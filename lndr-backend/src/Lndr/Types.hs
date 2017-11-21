{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE TemplateHaskell #-}

module Lndr.Types
    ( ServerState(..)
    , NickRequest(..)
    , NickInfo(..)
    , CreditRecord(..)
    , IssueCreditLog(IssueCreditLog)
    , RejectRecord(..)
    , Nonce(..)
    ) where

import           Data.Aeson
import           Data.Aeson.TH
import           Data.Either.Combinators (mapLeft)
import           Data.Hashable
import           Data.Text (Text)
import qualified Data.Text as T
import           Database.PostgreSQL.Simple
import           GHC.Generics
import           Network.Ethereum.Web3.Address (Address)
import qualified Network.Ethereum.Web3.Address as Addr
import           Servant.API
import qualified STMContainers.Bimap as Bimap
import qualified STMContainers.Map as Map

-- TODO remove this once Address derives Generic in hs-web3
instance Hashable Address where
    hashWithSalt x = hashWithSalt x . Addr.toText

instance ToHttpApiData Address where
  toUrlPiece = Addr.toText

instance FromHttpApiData Address where
  parseUrlPiece = mapLeft T.pack . Addr.fromText

newtype Nonce = Nonce { mkNonce :: Integer } deriving (Show, Generic)
instance ToJSON Nonce where
    toJSON (Nonce x) = toJSON x

data IssueCreditLog = IssueCreditLog { ucac :: Address
                                     , creditor :: Address
                                     , debtor :: Address
                                     , amount :: Integer
                                     , memo :: Text
                                     } deriving Show
$(deriveJSON defaultOptions ''IssueCreditLog)

-- `a` is a phantom type that indicates whether a record has been signed or not
data CreditRecord = CreditRecord { creditor :: Address
                                 , debtor :: Address
                                 , amount :: Integer
                                 , memo :: Text
                                 , submitter :: Address
                                 , nonce :: Integer
                                 , hash :: Text
                                 , signature :: Text
                                 } deriving (Show, Generic)
$(deriveJSON defaultOptions ''CreditRecord)

data RejectRecord = RejectRecord { rejectSig :: Text
                                 , hash :: Text
                                 }
$(deriveJSON defaultOptions ''RejectRecord)

data NickRequest = NickRequest { addr :: Address
                               , nick :: Text
                               , sig :: Text
                               }
$(deriveJSON defaultOptions ''NickRequest)

data NickInfo = NickInfo { addr :: Address
                         , nick :: Text
                         } deriving Show
$(deriveJSON defaultOptions ''NickInfo)

data ServerState = ServerState { pendingMap :: Map.Map Text CreditRecord
                               , dbConnection :: Connection
                               }
