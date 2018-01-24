{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Graphics.Wayland.WlRoots.Output
    ( WlrOutput
    , outputEnable
    , outputDisable
    , isOutputEnabled
    , makeOutputCurrent
    , swapOutputBuffers
    , getOutputPosition

    , effectiveResolution
    , destroyOutput

    , OutputMode(..)
    , setOutputMode

    , hasModes
    , getModes
    , getMode
    , getWidth
    , getHeight
    , getTransMatrix

    , OutputSignals(..)
    , getOutputSignals
    , getDataPtr

    , transformOutput
    , getOutputTransform

    , getEffectiveBox
    , getOutputBox
    , getOutputName
    , getOutputScale
    , setOutputScale

    , getMake
    , getModel
    , getSerial

    , getOutputNeedsSwap
    , setOutputNeedsSwap

    , destroyOutputGlobal
    , createOutputGlobal
    )
where

#include <wlr/types/wlr_output.h>

import Data.ByteString.Unsafe (unsafePackCString)
import Data.Int (Int32)
import Data.Text (Text)
import Data.Word (Word32, Word8)
import Foreign.C.Error (throwErrnoIf_)
import Foreign.C.Types (CInt(..))
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (Ptr, plusPtr, nullPtr)
import Foreign.Storable (Storable(..))

import Graphics.Wayland.WlRoots.Render.Matrix (Matrix(..))
import Graphics.Wayland.WlRoots.Box (WlrBox(..), Point (..))
import Graphics.Wayland.Signal (WlSignal)
import Graphics.Wayland.Server (OutputTransform(..))
import Graphics.Wayland.List (getListFromHead, istListEmpty)

import qualified Data.Text as T
import qualified Data.Text.Encoding as E

data WlrOutput

getOutputName :: Ptr WlrOutput -> IO Text
getOutputName = fmap E.decodeUtf8 . unsafePackCString . #{ptr struct wlr_output, name}

makeMaybe :: Text -> Maybe Text
makeMaybe txt = if T.null txt then Nothing else Just txt

getMake :: Ptr WlrOutput -> IO (Maybe Text)
getMake = fmap (makeMaybe . E.decodeUtf8) . unsafePackCString . #{ptr struct wlr_output, make}

getModel :: Ptr WlrOutput -> IO (Maybe Text)
getModel = fmap (makeMaybe . E.decodeUtf8) . unsafePackCString . #{ptr struct wlr_output, model}

getSerial :: Ptr WlrOutput -> IO (Maybe Text)
getSerial = fmap (makeMaybe . E.decodeUtf8) . unsafePackCString . #{ptr struct wlr_output, serial}

getOutputPosition :: Ptr WlrOutput -> IO Point
getOutputPosition ptr = do
    x :: Int32 <- #{peek struct wlr_output, lx} ptr
    y :: Int32 <- #{peek struct wlr_output, ly} ptr
    pure $ Point (fromIntegral x) (fromIntegral y)

foreign import ccall unsafe "wlr_output_enable" c_output_enable :: Ptr WlrOutput -> Bool -> IO ()

outputEnable :: Ptr WlrOutput -> IO ()
outputEnable = flip c_output_enable True

outputDisable :: Ptr WlrOutput -> IO ()
outputDisable = flip c_output_enable False

isOutputEnabled :: Ptr WlrOutput -> IO Bool
isOutputEnabled = fmap (/= (0 :: Word8)) . #{peek struct wlr_output, enabled}

foreign import ccall unsafe "wlr_output_make_current" c_make_current :: Ptr WlrOutput -> IO ()
makeOutputCurrent :: Ptr WlrOutput -> IO ()
makeOutputCurrent = c_make_current


foreign import ccall unsafe "wlr_output_swap_buffers" c_swap_buffers :: Ptr WlrOutput -> IO ()
swapOutputBuffers :: Ptr WlrOutput -> IO ()
swapOutputBuffers = c_swap_buffers


foreign import ccall unsafe "wlr_output_destroy" c_output_destroy :: Ptr WlrOutput -> IO ()

destroyOutput :: Ptr WlrOutput -> IO ()
destroyOutput = c_output_destroy


foreign import ccall unsafe "wlr_output_effective_resolution" c_effective_resolution :: Ptr WlrOutput -> Ptr CInt -> Ptr CInt -> IO ()

effectiveResolution :: Ptr WlrOutput -> IO (Int, Int)
effectiveResolution output = alloca $ \width -> alloca $ \height -> do
    c_effective_resolution output width height
    width_val <- peek width
    height_val <- peek height
    pure (fromIntegral width_val, fromIntegral height_val)

getEffectiveBox :: Ptr WlrOutput -> IO WlrBox
getEffectiveBox ptr = do
    phys <- getOutputBox ptr
    (width, height) <- effectiveResolution ptr
    pure phys {boxWidth = width, boxHeight = height}

foreign import ccall unsafe "wlr_output_set_transform" c_output_transform :: Ptr WlrOutput -> CInt -> IO ()

transformOutput :: Ptr WlrOutput -> OutputTransform -> IO ()
transformOutput ptr (OutputTransform x) =
    c_output_transform ptr (fromIntegral x)

getOutputTransform :: Ptr WlrOutput -> IO OutputTransform
getOutputTransform ptr = do
    val :: CInt <- #{peek struct wlr_output, transform} ptr
    pure $ OutputTransform (fromIntegral val)

data OutputMode = OutputMode
    { modeFlags   :: Word32
    , modeWidth   :: Word32
    , modeHeight  :: Word32
    , modeRefresh :: Word32
    }
    deriving (Eq, Show)

instance Storable OutputMode where
    alignment _ = #{alignment struct wlr_output_mode}
    sizeOf _ = #{size struct wlr_output_mode}
    peek ptr = OutputMode
        <$> #{peek struct wlr_output_mode, flags} ptr
        <*> #{peek struct wlr_output_mode, width} ptr
        <*> #{peek struct wlr_output_mode, height} ptr
        <*> #{peek struct wlr_output_mode, refresh} ptr
    poke = error "We do not poke output modes"

foreign import ccall unsafe "wlr_output_set_mode" c_set_mode :: Ptr WlrOutput -> Ptr OutputMode -> IO Bool

setOutputMode :: Ptr OutputMode -> Ptr WlrOutput -> IO ()
setOutputMode mptr ptr = 
    throwErrnoIf_ not "setOutputMode" $ c_set_mode ptr mptr


getWidth :: Ptr WlrOutput -> IO Int32
getWidth = #{peek struct wlr_output, width}

getHeight :: Ptr WlrOutput -> IO Int32
getHeight = #{peek struct wlr_output, height}

hasModes :: Ptr WlrOutput -> IO Bool
hasModes = fmap not . istListEmpty . #{ptr struct wlr_output, modes}

getModes :: Ptr WlrOutput -> IO [Ptr OutputMode]
getModes ptr = do
    let listptr = #{ptr struct wlr_output, modes} ptr
    getListFromHead listptr #{offset struct wlr_output_mode, link}

getMode :: Ptr WlrOutput -> IO (Maybe (Ptr OutputMode))
getMode ptr = do
    ret <- #{peek struct wlr_output, current_mode} ptr
    if ret == nullPtr
        then pure Nothing
        else pure $ Just ret

getTransMatrix :: Ptr WlrOutput -> Matrix
getTransMatrix = 
    Matrix . #{ptr struct wlr_output, transform_matrix}

data OutputSignals = OutputSignals
    { outSignalFrame :: Ptr (WlSignal ())
    , outSignalMode :: Ptr (WlSignal ())
    }

getOutputSignals :: Ptr WlrOutput -> OutputSignals
getOutputSignals ptr = 
    let frame      = #{ptr struct wlr_output, events.frame} ptr
        mode = #{ptr struct wlr_output, events.mode} ptr
     in OutputSignals
         { outSignalFrame = frame
         , outSignalMode = mode
         }

getDataPtr :: Ptr WlrOutput -> Ptr (Ptr a)
getDataPtr = #{ptr struct wlr_output, data}


getOutputBox :: Ptr WlrOutput -> IO WlrBox
getOutputBox ptr = do
    x :: Word32 <- #{peek struct wlr_output, lx} ptr
    y :: Word32 <- #{peek struct wlr_output, ly} ptr
    width :: Word32 <- #{peek struct wlr_output, width} ptr
    height :: Word32 <- #{peek struct wlr_output, height} ptr
    pure $ WlrBox (fromIntegral x) (fromIntegral y) (fromIntegral width) (fromIntegral height)

getOutputScale :: Ptr WlrOutput -> IO Float
getOutputScale = #{peek struct wlr_output, scale}

foreign import ccall unsafe "wlr_output_set_scale" c_set_scale :: Ptr WlrOutput -> Float -> IO ()

setOutputScale :: Ptr WlrOutput -> Float -> IO ()
setOutputScale = c_set_scale

getOutputNeedsSwap :: Ptr WlrOutput -> IO Bool
getOutputNeedsSwap = fmap (/= (0 :: Word8)) . #{peek struct wlr_output, needs_swap}

setOutputNeedsSwap :: Ptr WlrOutput -> Bool -> IO ()
setOutputNeedsSwap ptr val =
    #{poke struct wlr_output, needs_swap} ptr (if val then 1 else 0 :: Word8)

foreign import ccall "wlr_output_create_global" c_create_global :: Ptr WlrOutput -> IO ()

createOutputGlobal :: Ptr WlrOutput -> IO ()
createOutputGlobal = c_create_global

foreign import ccall "wlr_output_destroy_global" c_destroy_global :: Ptr WlrOutput -> IO ()

destroyOutputGlobal :: Ptr WlrOutput -> IO ()
destroyOutputGlobal = c_destroy_global
