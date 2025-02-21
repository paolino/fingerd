{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RecordWildCards #-}

module ExistentialController where

import Control.Applicative (empty)
import Control.Monad (msum, void)
import Control.Monad.Managed (Managed)
import Control.Monad.Morph (hoist)
import Control.Monad.Trans.Maybe
import Data.Attoparsec.ByteString (Parser, parseOnly, string, takeByteString)
import Data.Attoparsec.ByteString.Char8 (space)
import Data.ByteString.Char8 (ByteString)
import Data.Functor ((<&>))
import Data.Pool (Pool)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import Database.SQLite.Simple (Connection)
import Domain.Parser
import Domain.User (renderUser, renderUsers)
import Domain.UserService (deleteUser, getUser, getUsers, saveUser, updateUser)
import Repository.Database (WithPool)

-- | the simplest form of an handler
type RawHandler m = ByteString -> MaybeT m ByteString

-- | once we have an input to apply raw handlers form an alternative (MaybeT m)
runRawHandlers :: Monad m => [RawHandler m] -> RawHandler m
runRawHandlers xs input = msum $ xs <&> ($ input)

-- | we want to be able to split the RawHandler in its logic part + input parser + output renderer
data Handler m = forall i o.
  Handler
  { parser :: Parser i
  , handler :: i -> m o
  , renderer :: o -> ByteString
  }

-- | transform from high level lifting the parser failure out to MaybeT
runHandler :: Monad m => Handler m -> RawHandler m
runHandler Handler {..} input = case parseOnly parser input of
  Left _ -> empty
  Right x -> MaybeT $ Just . renderer <$> handler x

-- | the controller data are just a list of handlers
type Controller m = [Handler m]

-- | collapse the controller
runController :: Monad m => Controller m -> RawHandler m
runController = runRawHandlers . fmap runHandler

getUsersH :: Handler (WithPool Managed)
getUsersH = Handler
  do void $ string "\r\n"
  do const getUsers
  do renderUsers

getUserH :: Handler (WithPool Managed)
getUserH = Handler
  do T.strip . decodeUtf8 <$> takeByteString
  do getUser
  do renderUser

queryController :: Controller (WithPool Managed)
queryController = [getUsersH, getUserH]

editController :: Controller (WithPool Managed)
editController =
  [ Handler
      do string "+" >> space >> parseUserData
      do saveUser
      do encodeUtf8
  , Handler
      do string "-" >> space >> parseUserName
      do deleteUser
      do \b -> if b then "Ok" else "Could not delete user" 
  , Handler
      do string "~" >> space >> parseUserData
      do updateUser
      do \b -> if b then "Ok" else "Could not update user" 
  ]

-- (:) do Handler
--         do string "-" >> space >> parseUserName
-- (:) do Handler
--         do string "~" >> space >> parseUser

hoistHandler :: (forall a. m a -> n a) -> Handler m -> Handler n
hoistHandler f (Handler p g r) = Handler p (f . g) r

hoistController :: Functor f => (forall a. m a -> n a) -> f (Handler m) -> f (Handler n)
hoistController f = fmap $ hoistHandler f
