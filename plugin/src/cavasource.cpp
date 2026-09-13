#include "cavasource.hpp"

extern "C" {
#include <cavacore.h>
#include <config.h>
#include <input/common.h>
}

#include <QMetaObject>
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <pthread.h>
#include <thread>

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

// Nulled by ~CavaSource so a worker that outlives it never posts to a dead object.
struct CavaSource::OwnerLink {
    std::mutex lock;
    CavaSource* owner = nullptr;
};

struct CavaSource::Worker {
    std::shared_ptr<OwnerLink> link;
    quint64 generation = 0;
    std::atomic_bool stopping{false};

    void publish(const QVector<double>& values) {
        const std::lock_guard<std::mutex> guard(link->lock);
        CavaSource* owner = link->owner;
        if (owner == nullptr) {
            return;
        }
        QMetaObject::invokeMethod(
            owner,
            [owner, generation = generation, values]() { owner->receive(generation, values); },
            Qt::QueuedConnection);
    }
};

CavaSource::CavaSource(QObject* parent)
    : QObject(parent)
    , m_link(std::make_shared<OwnerLink>()) {
    m_link->owner = this;
    m_barLevels.fill(0.0, m_bars);
}

CavaSource::~CavaSource() {
    stop();
    const std::lock_guard<std::mutex> guard(m_link->lock);
    m_link->owner = nullptr;
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
        applyLevels(QVector<double>(m_bars, 0.0));
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
    if (m_worker) {
        return;
    }

    m_worker = std::make_shared<Worker>();
    m_worker->link = m_link;
    m_worker->generation = ++m_generation;
    std::thread(&CavaSource::run, m_worker, m_bars, m_source.toUtf8()).detach();
}

// Never joined: cava's input thread only sees `terminate` once PipeWire delivers a buffer.
void CavaSource::stop() {
    if (!m_worker) {
        return;
    }

    m_worker->stopping.store(true);
    m_worker.reset();
}

void CavaSource::receive(quint64 generation, const QVector<double>& values) {
    if (generation != m_generation || m_worker == nullptr) {
        return;
    }
    applyLevels(values);
}

void CavaSource::applyLevels(const QVector<double>& values) {
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
}

void CavaSource::run(std::shared_ptr<Worker> worker, int bars, QByteArray source) {
    std::atomic_bool& stopping = worker->stopping;
    while (!stopping.load()) {
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
            for (int tick = 0; tick < ParamPollTicks && !stopping.load(); ++tick) {
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
            while (!stopping.load()) {
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
                worker->publish(out);
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

        if (!stopping.load()) {
            worker->publish(QVector<double>(bars, 0.0));
            interruptibleSleep(std::chrono::duration_cast<std::chrono::milliseconds>(RestartDelay), stopping);
        }
    }
}
