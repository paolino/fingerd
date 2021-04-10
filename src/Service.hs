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

data Service = ServiceQueryK | ServiceEditK

data RequestG v a where
  GetUsersReq :: RequestG ServiceQueryK GetUsersK
  GetUserReq :: Text -> RequestG ServiceQueryK GetUserK
  SaveUserReq :: User -> RequestG ServiceEditK GetUserK
  DeleteUserReq :: UserName -> RequestG ServiceEditK GetUserK
  UpdateUserReq :: User -> RequestG ServiceEditK GetUserK

data ResponseG v a where
  GetUsersResp :: [UserName] -> ResponseG ServiceQueryK GetUsersK
  GetUserResp :: Maybe User -> ResponseG ServiceQueryK GetUserK
  SaveUserResp :: ResponseG ServiceEditK GetUserK
  DeleteUserResp :: ResponseG ServiceEditK GetUserK
  UpdateUserResp :: ResponseG ServiceEditK GetUserK

newtype RespondG v m = RespondG (forall a. RequestG v a -> m (ResponseG v a))

serialize :: ResponseG v a -> ByteString
serialize (GetUserResp n) = renderUser n
serialize (GetUsersResp n) = renderUsers n
serialize _ = "OK"
