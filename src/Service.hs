{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

module Service where

import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.List (intersperse)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Domain.User (User (..), UserName, renderUser, renderUsers)

data RequestK = GetUserK | GetUsersK | SaveUserK | DeleteUserK | UpdateUserK 

data Via = ViaUserK | ViaManagementK 
data RequestG v a where
  GetUsersReq :: RequestG ViaUserK GetUsersK
  GetUserReq :: Text -> RequestG ViaUserK GetUserK
  SaveUserReq :: User -> RequestG ViaManagementK GetUserK
  DeleteUserReq :: UserName -> RequestG ViaManagementK GetUserK
  UpdateUserReq :: User -> RequestG ViaManagementK GetUserK


data ResponseG v a where
  GetUsersResp :: [UserName] -> ResponseG ViaUserK GetUsersK
  GetUserResp :: Maybe User -> ResponseG ViaUserK GetUserK
  SaveUserResp :: ResponseG ViaManagementK GetUserK
  DeleteUserResp :: ResponseG ViaManagementK GetUserK
  UpdateUserResp :: ResponseG ViaManagementK GetUserK

newtype RespondG v m = RespondG (forall a . RequestG v a -> m (ResponseG v a))

serialize :: ResponseG v a -> ByteString
serialize (GetUserResp n) = renderUser n
serialize (GetUsersResp n) = renderUsers n
serialize _ = "OK"
