{-# LANGUAGE BlockArguments #-}

module TCPServer where

import Control.Monad (forever, void)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Text (Text)
import Data.Text.Encoding ( decodeUtf8 )
import Network.Socket
  ( AddrInfo (addrAddress, addrFamily, addrFlags)
  , AddrInfoFlag (AI_PASSIVE)
  , Socket
  , SocketType (Stream)
  , accept
  , bind
  , close
  , defaultHints
  , defaultProtocol
  , getAddrInfo
  , listen
  , socket
  , withSocketsDo, ServiceName
  )
import Network.Socket.ByteString (recv, send, sendAll)
import Service 
import Control.Monad.Managed
    ( runManaged, MonadIO(liftIO), Managed )
import Data.ByteString.Internal (w2c)
import Domain.User

{- logAndEcho :: Socket -> IO ()
logAndEcho sock = forever $ do
  (soc, _) <- accept sock
  printAndKickback soc
  close soc
  where
    printAndKickback conn = do
      msg <- recv conn 1024
      print msg
      sendAll conn msg -}

server :: ServiceName -> RespondG Managed -> IO ()
server port respond = withSocketsDo $ do
  serveraddr : _ <- getAddrInfo
    do Just $ defaultHints {addrFlags = [AI_PASSIVE]}
    do Nothing
    do Just port
  sock <- socket (addrFamily serveraddr) Stream defaultProtocol
  bind sock (addrAddress serveraddr)
  listen sock 1
  runManaged $ handleQueries respond sock
  close sock

handleQuery :: RespondG Managed -> Socket -> Managed ()
handleQuery (RespondG respond) soc = void $ do
  msg <- liftIO $ recv soc 1024
  liftIO . send soc =<< case msg of
    "\r\n" -> serialize <$> respond UsersReq
    name -> serialize <$> respond (UserReq $ decodeUtf8 name)

handleQueries :: RespondG Managed -> Socket -> Managed ()
handleQueries respond sock = forever $ do
  (soc, _) <- liftIO $ accept sock  
  liftIO $ putStrLn "got connection, handling query"
  handleQuery respond soc
  liftIO $ close soc


handleEdits :: EditRespond Managed -> Socket -> Managed ()
handleEdits respond sock = forever $ do
  (soc, _) <- liftIO $ accept sock  
  liftIO $ putStrLn "got connection, handling query"
  handleEdit respond soc
  liftIO $ close soc

handleEdit :: EditRespond Managed -> Socket -> Managed ()
handleEdit respond soc = void $ do
  msg <- liftIO $ recv soc 1024
  let cmd = BS.head msg
  liftIO . send soc =<< case w2c cmd of
    '+' -> respond $ SaveUser user
    '-' -> respond $ DeleteUser $ decodeUtf8 $ BS.tail msg
    '~' -> respond $ UpdateUser user
    where user :: User
          -- TODO user from string
          user = undefined

serverForEdit :: ServiceName -> EditRespond Managed -> IO ()
serverForEdit port respond = withSocketsDo $ do
  serveraddr : _ <- getAddrInfo
    do Just $ defaultHints {addrFlags = [AI_PASSIVE]}
    do Nothing
    do Just port
  sock <- socket (addrFamily serveraddr) Stream defaultProtocol
  bind sock (addrAddress serveraddr)
  listen sock 1
  runManaged $ handleEdits respond sock
  close sock
