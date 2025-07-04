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

#include "ldCore/Helpers/Sound/ldSoundEffects.h"

#include <QtCore/QDebug>
#include <QtCore/QThread>

ldSoundEffects::ldSoundEffects()
    : m_thread(new QThread())
{
    m_thread->start();
}

ldSoundEffects::~ldSoundEffects()
{
    stopAll();
    m_thread->quit();
    if(!m_thread->wait(500)) {
        qWarning() << this << __FUNCTION__ << "emergency thread termination";
        m_thread->terminate();
        m_thread->wait(500);
    }
}

void ldSoundEffects::insert(int sfx, const QString &resourcePath)
{
    m_soundMap[sfx] = std::unique_ptr<ldQSound>(new ldQSound(resourcePath));
    m_soundMap[sfx]->moveToThread(m_thread.get());
}

void ldSoundEffects::play(int sfx)
{
    if(!m_enabled) {
        return;
    }

    m_soundMap[sfx]->play();
}

void ldSoundEffects::stop(int sfx)
{
    m_soundMap[sfx]->stop();
}

void ldSoundEffects::stopAll()
{
    for(auto &item : m_soundMap)
        item.second->stop();
}

void ldSoundEffects::setLoops(int sfx, int loops)
{
    m_soundMap[sfx]->setLoops(loops);
}

bool ldSoundEffects::isSoundEnabled() const
{
    return m_enabled;
}

void ldSoundEffects::setSoundEnabled(bool enabled)
{
    m_enabled = enabled;
    if(!m_enabled) {
        stopAll();
    }
}

void ldSoundEffects::setSoundLevel(int soundLevel)
{
    for(auto &kv : m_soundMap) {
        kv.second->setVolumeLevel(soundLevel);
    }
}

ldQSound *ldSoundEffects::operator [](int i)
{
    return m_soundMap[i].get();
}
