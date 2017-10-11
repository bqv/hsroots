{-# LANGUAGE EmptyDataDecls #-}
module Graphics.Wayland.WlRoots.XWayland
    ( XWayland
    , xwaylandCreate

    , X11Surface
    , getXWindows
    , x11WindowGetSurface
    )
where

#include <wlr/xwayland.h>

import Foreign.C.Error (throwErrnoIfNull)
import Foreign.Ptr (Ptr, plusPtr)
import Foreign.Storable (Storable(..))
import Graphics.Wayland.List (getListFromHead)
import Graphics.Wayland.Resource (getUserData)
import Graphics.Wayland.Server (DisplayServer (..))
import Graphics.Wayland.WlRoots.Compositor (WlrCompositor)
import Graphics.Wayland.WlRoots.Surface (WlrSurface)

data XWayland

foreign import ccall unsafe "wlr_xwayland_create" c_xwayland_create :: Ptr DisplayServer -> Ptr WlrCompositor -> IO (Ptr XWayland)
xwaylandCreate :: DisplayServer -> Ptr WlrCompositor -> IO (Ptr XWayland)
xwaylandCreate (DisplayServer ptr) comp =
    throwErrnoIfNull "xwaylandCreate" $ c_xwayland_create ptr comp

data X11Surface

getXWindows :: Ptr XWayland -> IO [Ptr X11Surface]
getXWindows xway = 
    let list = #{ptr struct wlr_xwayland, displayable_surfaces} xway
     in getListFromHead list #{offset struct wlr_xwayland_surface, link}

x11WindowGetSurface :: Ptr X11Surface -> IO (Ptr WlrSurface)
x11WindowGetSurface =
    fmap getUserData . #{peek struct wlr_xwayland_surface, surface}
