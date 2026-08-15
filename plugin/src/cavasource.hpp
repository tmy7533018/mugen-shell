#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QVariantList>
#include <QVector>
#include <atomic>
#include <thread>

/// Audio spectrum from libcava. `source` takes a PipeWire node name, or "auto"
/// for the default sink's monitor and "auto_input" for the default source.
class CavaSource : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(int bars READ bars WRITE setBars NOTIFY barsChanged)
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QVariantList barLevels READ barLevels NOTIFY levelsChanged)
    Q_PROPERTY(qreal audioLevel READ audioLevel NOTIFY levelsChanged)
    Q_PROPERTY(qreal rms READ rms NOTIFY levelsChanged)

public:
    explicit CavaSource(QObject* parent = nullptr);
    ~CavaSource() override;

    bool active() const { return m_active; }
    void setActive(bool active);

    int bars() const { return m_bars; }
    void setBars(int bars);

    QString source() const { return m_source; }
    void setSource(const QString& source);

    QVariantList barLevels() const { return m_barLevels; }
    qreal audioLevel() const { return m_audioLevel; }
    qreal rms() const { return m_rms; }

signals:
    void activeChanged();
    void barsChanged();
    void sourceChanged();
    void levelsChanged();

private:
    void start();
    void stop();
    void restart();
    void run(int bars, QByteArray source);
    void publish(QVector<double> values);

    bool m_active = false;
    int m_bars = 16;
    QString m_source = QStringLiteral("auto");

    QVariantList m_barLevels;
    qreal m_audioLevel = 0.0;
    qreal m_rms = 0.0;

    std::thread m_worker;
    std::atomic_bool m_stopping{false};
};
