#include <QApplication>
#include <QQuickView>
#include <QtQml>
#include <QDebug>

#include "govalue.h"
#include "govaluetype.h"
#include "capi.h"

#include <QDebug>

void newGuiApplication()
{
    static char empty[1] = {0};
    static char *argv[] = {empty};
    static int argc = 1;
    new QGuiApplication(argc, argv);
}

void applicationExec()
{
    qApp->exec();
}

void *currentThread()
{
    return QThread::currentThread();
}

void *appThread()
{
    return QCoreApplication::instance()->thread();
}

QQmlEngine_ *newEngine(QObject_ *parent)
{
    return new QQmlEngine(reinterpret_cast<QObject *>(parent));
}

void delEngine(QQmlEngine_ *engine)
{
    QQmlEngine *qengine = reinterpret_cast<QQmlEngine *>(engine);
    delete qengine;
}

QQmlContext_ *engineRootContext(QQmlEngine_ *engine)
{
    return reinterpret_cast<QQmlEngine *>(engine)->rootContext();
}

QQmlComponent_ *newComponent(QQmlEngine_ *engine, QObject_ *parent)
{
    QQmlEngine *qengine = reinterpret_cast<QQmlEngine *>(engine);
    //QObject *qparent = reinterpret_cast<QObject *>(parent);
    return new QQmlComponent(qengine);
}

void componentSetData(QQmlComponent_ *component, const char *data, int dataLen, const char *url, int urlLen)
{
    QByteArray qdata(data, dataLen);
    QByteArray qurl(url, urlLen);
    QString qsurl = QString::fromUtf8(qurl);
    reinterpret_cast<QQmlComponent *>(component)->setData(qdata, qsurl);
}

char *componentErrorString(QQmlComponent_ *component)
{
    QQmlComponent *qcomponent = reinterpret_cast<QQmlComponent *>(component);
    if (qcomponent->isReady()) {
        return NULL;
    }
    if (qcomponent->isError()) {
        QByteArray ba = qcomponent->errorString().toUtf8();
        return strdup(ba.constData());
    }
    return strdup("component is not ready (why!?)");
}

QObject_ *componentCreate(QQmlComponent_ *component, QQmlContext_ *context)
{
    QQmlComponent *qcomponent = reinterpret_cast<QQmlComponent *>(component);
    QQmlContext *qcontext = reinterpret_cast<QQmlContext *>(context);

    return qcomponent->create(qcontext);
}

QQuickView_ *componentCreateView(QQmlComponent_ *component, QQmlContext_ *context)
{
    QQmlComponent *qcomponent = reinterpret_cast<QQmlComponent *>(component);
    QQmlContext *qcontext = reinterpret_cast<QQmlContext *>(context);

    QObject *obj = qcomponent->create(qcontext);
    QQuickView *view = new QQuickView(qcontext->engine(), 0);
    view->setContent(qcomponent->url(), qcomponent, obj);
    return view;
}

void viewShow(QQuickView_ *view)
{
    reinterpret_cast<QQuickView *>(view)->show();
}

void contextSetObject(QQmlContext_ *context, QObject_ *value)
{
    QQmlContext *qcontext = reinterpret_cast<QQmlContext *>(context);
    QObject *qvalue = reinterpret_cast<QObject *>(value);

    qcontext->setContextObject(qvalue);
}

void contextSetProperty(QQmlContext_ *context, QString_ *name, DataValue *value)
{
    const QString *qname = reinterpret_cast<QString *>(name);
    QQmlContext *qcontext = reinterpret_cast<QQmlContext *>(context);

    QVariant var;
    unpackDataValue(value, &var);
    qcontext->setContextProperty(*qname, var);
}

void contextGetProperty(QQmlContext_ *context, QString_ *name, DataValue *value)
{
    QQmlContext *qcontext = reinterpret_cast<QQmlContext *>(context);
    const QString *qname = reinterpret_cast<QString *>(name);

    QVariant var = qcontext->contextProperty(*qname);
    packDataValue(&var, value);
}

void objectGetProperty(QObject_ *object, const char *name, DataValue *value)
{
    QObject *qobject = reinterpret_cast<QObject *>(object);
    
    QVariant var = qobject->property(name);
    packDataValue(&var, value);
}

QString_ *newString(const char *data, int len)
{
    // This will copy data only once.
    QByteArray ba = QByteArray::fromRawData(data, len);
    return new QString(ba);
}

void delString(QString_ *s)
{
    delete reinterpret_cast<QString *>(s);
}

QObject_ *newValue(GoAddr *addr, GoTypeInfo *typeInfo)
{
    return new GoValue(addr, typeInfo);
}

void unpackDataValue(DataValue *value, QVariant_ *var)
{
    QVariant *qvar = reinterpret_cast<QVariant *>(var);
    switch (value->dataType) {
    case DTString:
        *qvar = QString::fromUtf8(*(char **)value->data, value->len);
        break;
    case DTBool:
        *qvar = bool(*(char *)(value->data) != 0);
        break;
    case DTInt64:
        *qvar = *(qint64*)(value->data);
        break;
    case DTInt32:
        *qvar = *(qint32*)(value->data);
        break;
    case DTFloat64:
        *qvar = *(double*)(value->data);
        break;
    case DTFloat32:
        *qvar = *(float*)(value->data);
        break;
    case DTObject:
        qvar->setValue(*(QObject**)(value->data));
        break;
    default:
        qFatal("Unsupported data type: %d", value->dataType);
        break;
    }
}

void packDataValue(QVariant_ *var, DataValue *value)
{
    QVariant *qvar = reinterpret_cast<QVariant *>(var);

    // Some assumptions are made below regarding the size of types.
    // There's apparently no better way to handle this since that's
    // how the types with well defined sizes (qint64) are mapped to
    // meta-types (QMetaType::LongLong).
    switch (qvar->type()) {
    case QMetaType::QString:
        {
            value->dataType = DTString;
            QByteArray ba = qvar->toByteArray();
            *(char**)(value->data) = strdup(ba.constData());
            value->len = ba.size();
            break;
        }
    case QMetaType::Bool:
        value->dataType = DTBool;
        *(qint8*)(value->data) = (qint8)qvar->toInt();
        break;
    case QMetaType::LongLong:
        value->dataType = DTInt64;
        *(qint64*)(value->data) = qvar->toLongLong();
        break;
    case QMetaType::Int:
        value->dataType = DTInt32;
        *(qint32*)(value->data) = qvar->toInt();
        break;
    case QMetaType::Double:
        value->dataType = DTFloat64;
        *(double*)(value->data) = qvar->toDouble();
        break;
    case QMetaType::Float:
        value->dataType = DTFloat32;
        *(float*)(value->data) = qvar->toFloat();
        break;
    case QMetaType::QObjectStar:
        {
            QObject *qobject = qvar->value<QObject *>();
            GoValue *govalue = dynamic_cast<GoValue *>(qobject);
            if (govalue) {
                value->dataType = DTGoAddr;
                *(void **)(value->data) = govalue->addr();
                break;
            }
        }
        // fallthrough
    default:
        qFatal("Unsupported variant type: %d", qvar->type());
        break;
    }
}

int gqRunSpike(GoAddr *addr, GoTypeInfo *typeInfo)
{
    int argc = 1;
    const char *argv[] = {""};

    QGuiApplication app(argc, (char **)argv);
    QQuickView view;

    GoValue value(addr, typeInfo);
    view.rootContext()->setContextProperty("value", &value);

    GoValueType<1>::init(typeInfo);
    qmlRegisterType< GoValueType<1> >("GoTypes", 1, 0, typeInfo->typeName);

    view.setSource(QUrl::fromLocalFile("spike.qml"));
    view.show();

    return app.exec();
}

void internalLogHandler(QtMsgType severity, const QMessageLogContext &context, const QString &text)
{
    QByteArray textba = text.toUtf8();
    LogMessage message = {severity, textba.constData(), textba.size(), context.file, strlen(context.file), context.line};
    hookLogHandler(&message);
}

void installLogHandler()
{
    qInstallMessageHandler(internalLogHandler);
}

// vim:ts=4:sw=4:et:ft=cpp
