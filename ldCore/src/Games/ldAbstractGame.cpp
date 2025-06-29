/**
    libLaserdockCore
    Copyright(c) 2018 Wicked Lasers

    This file is part of libLaserdockCore.

    libLaserdockCore is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    libLaserdockCore is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with libLaserdockCore.  If not, see <https://www.gnu.org/licenses/>.
**/

#include "ldCore/Games/ldAbstractGame.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QtDebug>
#include <QtGui/QtEvents>
#include <QtQml/QQmlEngine>

#include <ldCore/ldCore.h>
#include <ldCore/Helpers/ldEnumHelper.h>
#include <ldCore/Visualizations/ldVisualizationTask.h>

void ldAbstractGame::registerMetaTypes()
{
#ifdef LD_CORE_ENABLE_QT_QUICK
    qmlRegisterUncreatableType<ldAbstractGame>("WickedLasers", 1, 0, "LdGameState", "LdGameState enum can't be created");
#endif
    ldGamepad::registerMetaTypes();
}

ldAbstractGame::ldAbstractGame(const QString &id, const QString &title, QObject *parent)
    : QObject(parent)
    , m_id(id)
    , m_title(title)
    , m_gamepadCtrl(new ldGamepadCtrl(this, this))
    , m_isActive(false)
    , m_levelIndex(0)
{
#ifdef LD_CORE_ENABLE_QT_QUICK
    qmlRegisterAnonymousType<ldGamepadCtrl>("WickedLasers", 1);
#endif

    connect(this, &ldAbstractGame::levelIndexChanged, this, &ldAbstractGame::onLevelIndexChanged);
    connect(this, &ldAbstractGame::isActiveChanged, this, &ldAbstractGame::onActiveChanged);

#ifdef LD_CORE_GAMES_ALWAYS_PLAY_STATE
    connect(this, &ldAbstractGame::stateChanged, this, [&](int state) {
       if(state == Ready)
           play();
    });
#endif

    m_gamepadCtrl->installEventFilter(this);
}

ldAbstractGame::~ldAbstractGame()
{
}

QStringList ldAbstractGame::get_levelList() const
{
    return m_levelList;
}

QString ldAbstractGame::get_levelListName() const
{
    return m_levelListName;
}

QStringList ldAbstractGame::get_keyDescriptions() const
{
    return m_keyDescriptions;
}

bool ldAbstractGame::eventFilter(QObject *obj, QEvent *ev) {
    if (!filterKeyEvent()) {
        return QObject::eventFilter(obj, ev);
    }

    if(ev->type() == QEvent::KeyPress || ev->type() == QEvent::KeyRelease) {
        QKeyEvent *keyEvent = dynamic_cast<QKeyEvent*>(ev);
        Q_ASSERT(keyEvent);
        if(keyEvent->modifiers() == Qt::NoModifier
                || keyEvent->modifiers() == Qt::KeypadModifier ) {
            if(handleKeyEvent(keyEvent)) {
                keyEvent->accept();
                return true;
            }
        }
    }

    return QObject::eventFilter(obj, ev);
}

ldAbstractGameVisualizer *ldAbstractGame::getVisualizer() const
{
    return getGameVisualizer();
}

void ldAbstractGame::moveX(double x)
{
    getGameVisualizer()->moveX(x);
}

void ldAbstractGame::moveY(double y)
{
    getGameVisualizer()->moveY(y);
}

void ldAbstractGame::moveRightX(double x)
{
    getGameVisualizer()->moveRightX(x);
}

void ldAbstractGame::moveRightY(double y)
{
    getGameVisualizer()->moveRightY(y);
}

int ldAbstractGame::get_state() const
{
    return ldEnumHelper::as_integer(getGameVisualizer()->state());
}

int ldAbstractGame::get_playingState() const
{
    return ldEnumHelper::as_integer(getGameVisualizer()->playingState());
}

void ldAbstractGame::play()
{
    if(get_state() != Playing)
        toggle();
}

void ldAbstractGame::pause()
{
    if(get_state() == Playing)
        toggle();
}

void ldAbstractGame::reset() {
    getGameVisualizer()->reset();
}

void ldAbstractGame::toggle() {
    qDebug() << "Game:" << get_title() << "isPlaying changed to" << get_state();

    getGameVisualizer()->togglePlay();
}

bool ldAbstractGame::isSoundEnabled() const
{
    return getGameVisualizer()->isSoundEnabled();
}

void ldAbstractGame::setSoundEnabled(bool enabled)
{
    getGameVisualizer()->setSoundEnabled(enabled);
}

void ldAbstractGame::setSoundLevel(int soundLevel)
{
    getGameVisualizer()->setSoundLevel(soundLevel);
}

void ldAbstractGame::activate()
{
    connect(getGameVisualizer(), &ldAbstractGameVisualizer::stateChanged, this, &ldAbstractGame::onGameStateChanged, Qt::UniqueConnection);
    connect(getGameVisualizer(), &ldAbstractGameVisualizer::playingStateChanged, this, &ldAbstractGame::onPlayingStateChanged, Qt::UniqueConnection);
    //  visualizer
    ldCore::instance()->task()->setVisualizer(getGameVisualizer());
#ifdef LD_CORE_GAMES_ALWAYS_PLAY_STATE
//    play();
#endif
}

void ldAbstractGame::deactivate()
{
    //    pause();
}

bool ldAbstractGame::filterKeyEvent() const {
    return get_state() == ldAbstractGame::Playing;
}

void ldAbstractGame::onGameStateChanged(const ldAbstractGameVisualizer::ldGameState &state)
{
    emit stateChanged(ldEnumHelper::as_integer(state));
}

void ldAbstractGame::onPlayingStateChanged(const ldAbstractGameVisualizer::ldPlayingState &state)
{
    emit playingStateChanged(ldEnumHelper::as_integer(state));
}

void ldAbstractGame::onActiveChanged(bool isActive)
{
    if(isActive) {
        activate();
    } else {
        deactivate();
    }
}

void ldAbstractGame::onLevelIndexChanged(int index)
{
    getGameVisualizer()->setLevelIndex(index);
}

