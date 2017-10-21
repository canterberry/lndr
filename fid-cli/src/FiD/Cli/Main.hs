{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-cse #-}

module FiD.Cli.Main
    ( main
    ) where

import           Data.Either.Combinators (rightToMaybe)
import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as LT
import           Dhall hiding (Text)
import           Network.Ethereum.Web3
import qualified Network.Ethereum.Web3.Address as Addr
import           Network.Ethereum.Web3.Api
import           Network.Ethereum.Web3.Types
import           System.Console.CmdArgs hiding (auto)

-- TODO can I get rid of this redundant configFile param via Cmd Product Type?
data FiDCmd = Info    {config :: Text, scope :: Text}
            | Request {config :: Text, debtor :: Text, amount :: Integer}
            | Send    {config :: Text, creditor :: Text, amount :: Integer}
            deriving (Show, Data, Typeable)

--  validate these to make sure they're all valid
--  should they all be integers? why not?
--  is there aleardy an efficient uint256 type in haskell?
data IssueCreditLog = IssueCreditLog { ucac :: Address
                                     , creditor :: Address
                                     , debtor :: Address
                                     , amount :: Text -- TOOD Uint256
                                     } deriving Show

data FiDConfig = FiDConfig { fidAddress :: Text
                           , cpAddress :: Text
                           , userAddress :: Text
                           } deriving (Show, Generic)

instance Interpret FiDConfig

main :: IO ()
main = do mode <- cmdArgs (modes [Info "" "fid", Request "" "" 0, Send "" "" 0])
          let configFilePath = config mode
          config <- input auto $ LT.fromStrict configFilePath
          runMode config mode

runMode :: FiDConfig -> FiDCmd -> IO ()
runMode config (Info _ "fid") = print =<< runWeb3 (fidLogs config)
runMode _ (Info _ "all") = print =<< runWeb3 allLogs
runMode _ _ = putStrLn "Not yet implemented"

-- fetch all logs
-- terminal equivalent: curl -X POST --data {"jsonrpc":"2.0","method":"eth_getLogs","params":[{"fromBlock": "0x0"}],"id":73} localhost:8545
allLogs :: Provider a => Web3 a [Change]
allLogs = eth_getLogs (Filter Nothing Nothing (Just "0x0") Nothing)

-- fetch cp logs related to FiD UCAC
-- verify that these are proper logs
fidLogs :: Provider a => FiDConfig -> Web3 a [Either String IssueCreditLog]
fidLogs config = fmap interpretUcacLog <$>
    -- TODO throw and error if `Addr.fromText` returns `Left`
    eth_getLogs (Filter (rightToMaybe . Addr.fromText $ cpAddress config)
                        Nothing
                        (Just "0x0") -- start from block 0
                        Nothing)

-- transforms the standard ('0x' + 64-char) bytes32 rendering of a log field into the
-- 40-char hex representation of an address
bytes32ToAddress :: Text -> Text
bytes32ToAddress = T.drop 26

interpretUcacLog :: Change -> Either String IssueCreditLog
interpretUcacLog change = do creditorAddr <- Addr.fromText . bytes32ToAddress . (!! 2) $ changeTopics change
                             debtorAddr <- Addr.fromText . bytes32ToAddress . (!! 3) $ changeTopics change
                             pure $ IssueCreditLog (changeAddress change)
                                                   creditorAddr
                                                   debtorAddr
                                                   (changeData change)

-- fetch cp logs related to a particular users use of the FiD UCAC

-- fetch cp logs related to a particular users use of the FiD UCAC
