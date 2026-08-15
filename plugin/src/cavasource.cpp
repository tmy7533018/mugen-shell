#include "cavasource.hpp"

extern "C" {
#include <cavacore.h>
#include <config.h>
#include <input/common.h>
}

#include <QMetaObject>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <pthread.h>

namespace {

// cava's own PipeWire defaults, which scripts/cava.sh inherited by leaving them unset.
constexpr unsigned int SampleRate = 48000;
constexpr int SampleBits = 16;
constexpr int Channels = 1;
constexpr int AutoConnect = 2;
constexpr double NoiseReduction = 0.77;
constexpr int LowCutOff = 50;
constexpr int HighCutOff = 8000;
constexpr int AutoSens = 1;

constexpr int CavaBufferSize = 16384;
constexpr auto FramePeriod = std::chrono::milliseconds(16);
constexpr auto ParamPollPeriod = std::chrono::milliseconds(1);
constexpr int ParamPollTicks = 5000;
constexpr auto RestartDelay = std::chrono::seconds(5);

// fftw's planner is not thread-safe, so concurrent cava_init/cava_destroy segfaults.
std::mutex& planLock() {
    static std::mutex lock;
    return lock;
}

void interruptibleSleep(std::chrono::milliseconds total, const std::atomic_bool& cancelled) {
    constexpr auto slice = std::chrono::milliseconds(50);
    for (auto waited = std::chrono::milliseconds(0); waited < total && !cancelled.load(); waited += slice) {
        std::this_thread::sleep_for(slice);
    }
}

} // namespace

CavaSource::CavaSource(QObject* parent)
    : QObject(parent) {
    m_barLevels.fill(0.0, m_bars);
}

CavaSource::~CavaSource() {
    stop();
}

void CavaSource::setActive(bool active) {
    if (m_active == active) {
        return;
    }

    m_active = active;
    emit activeChanged();

    if (active) {
        start();
    } else {
        stop();
        publish(QVector<double>(m_bars, 0.0));
    }
}

void CavaSource::setBars(int bars) {
    if (bars < 1 || m_bars == bars) {
        return;
    }

    m_bars = bars;
    emit barsChanged();
    restart();
}

void CavaSource::setSource(const QString& source) {
    if (m_source == source) {
        return;
    }

    m_source = source;
    emit sourceChanged();
    restart();
}

void CavaSource::restart() {
    if (!m_active) {
        return;
    }

    stop();
    start();
}

void CavaSource::start() {
    if (m_worker.joinable()) {
        return;
    }

    m_stopping.store(false);
    m_worker = std::thread(&CavaSource::run, this, m_bars, m_source.toUtf8());
}

void CavaSource::stop() {
    if (!m_worker.joinable()) {
        return;
    }

    m_stopping.store(true);
    m_worker.join();
}

void CavaSource::publish(QVector<double> values) {
    QMetaObject::invokeMethod(
        this,
        [this, values]() {
            // A replaced worker's frames outlive it in the event queue.
            if (values.size() != m_bars) {
                return;
            }

            QVariantList levels;
            levels.reserve(values.size());

            double peak = 0.0;
            double sum = 0.0;
            for (const double value : values) {
                levels.append(value);
                peak = std::max(peak, value);
                sum += value;
            }

            m_barLevels = levels;
            m_audioLevel = peak;
            m_rms = values.isEmpty() ? 0.0 : sum / values.size();
            emit levelsChanged();
        },
        Qt::QueuedConnection);
}

void CavaSource::run(int bars, QByteArray source) {
    while (!m_stopping.load()) {
        struct audio_data audio;
        struct config_params prm;
        std::memset(&audio, 0, sizeof(audio));
        std::memset(&prm, 0, sizeof(prm));

        prm.input = INPUT_PIPEWIRE;
        prm.audio_source = source.data();
        prm.samplerate = SampleRate;
        prm.samplebits = SampleBits;
        prm.channels = Channels;
        prm.autoconnect = AutoConnect;
        prm.active = 1;
        prm.remix = 1;
        prm.virtual_node = 1;

        audio.format = -1;
        audio.rate = 0;
        audio.channels = Channels;
        audio.input_buffer_size = BUFFER_SIZE * Channels;
        audio.cava_buffer_size = CavaBufferSize;

        pthread_mutex_init(&audio.lock, nullptr);

        // get_input allocates audio.cava_in and audio.source off prm.
        const ptr inputFn = get_input(&audio, &prm);
        pthread_t inputThread;
        const bool spawned = inputFn != nullptr && pthread_create(&inputThread, nullptr, inputFn, &audio) == 0;

        struct cava_plan* plan = nullptr;
        if (spawned) {
            for (int tick = 0; tick < ParamPollTicks && !m_stopping.load(); ++tick) {
                std::this_thread::sleep_for(ParamPollPeriod);
                pthread_mutex_lock(&audio.lock);
                const bool ready = audio.threadparams == 0 && audio.format != -1 && audio.rate != 0;
                pthread_mutex_unlock(&audio.lock);
                if (ready) {
                    const std::lock_guard<std::mutex> guard(planLock());
                    plan = cava_init(bars, audio.rate, audio.channels, AutoSens, NoiseReduction, LowCutOff, HighCutOff);
                    break;
                }
            }
        }

        // The packaged headers only forward-declare cava_plan, so status is unreadable.
        if (plan != nullptr) {
            QVector<double> out(bars);
            while (!m_stopping.load()) {
                std::this_thread::sleep_for(FramePeriod);

                pthread_mutex_lock(&audio.lock);
                // input_pipewire raises terminate itself when the stream dies.
                const bool lost = audio.terminate != 0;
                if (!lost) {
                    cava_execute(audio.cava_in, audio.samples_counter, out.data(), plan);
                    audio.samples_counter = 0;
                }
                pthread_mutex_unlock(&audio.lock);

                if (lost) {
                    break;
                }
                publish(out);
            }
        }

        if (spawned) {
            pthread_mutex_lock(&audio.lock);
            audio.terminate = 1;
            pthread_mutex_unlock(&audio.lock);
            pthread_join(inputThread, nullptr);
        }

        if (plan != nullptr) {
            const std::lock_guard<std::mutex> guard(planLock());
            cava_destroy(plan);
        }
        pthread_mutex_destroy(&audio.lock);
        std::free(audio.cava_in);
        std::free(audio.source);

        if (!m_stopping.load()) {
            publish(QVector<double>(bars, 0.0));
            interruptibleSleep(std::chrono::duration_cast<std::chrono::milliseconds>(RestartDelay), m_stopping);
        }
    }
}
