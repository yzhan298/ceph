// -*- mode:C++; tab-width:8; c-basic-offset:2; indent-tabs-mode:t -*-
// vim: ts=8 sw=2 smarttab
#pragma once

#include <memory>

#include "admin_socket.h"

namespace crimson::admin {

class OsdStatusHook;
class SendBeaconHook;
class ConfigShowHook;
class ConfigGetHook;
class ConfigSetHook;
class AssertAlwaysHook;

template<class Hook, class... Args>
std::unique_ptr<AdminSocketHook> make_asok_hook(Args&&... args);

}  // namespace crimson::admin
