module Main where
    
import Control.Exception
import System.Exit

import Options.Applicative
import Options.Applicative.Help.Pretty
import Options.Applicative.Help.Chunk
import Options.Applicative.Help.Core (parserUsage)

import System.Environment (getArgs)

import Prelude hiding (putStrLn)
import Data.Maybe (maybeToList)

import VabalMain
import VabalConfigure
import VabalUpdate

import UserInterface

data Command = Update
             | Main VabalMainArguments
             | Configure [String] [String]

vabalHeader :: String
vabalHeader = "vabal - The Cabal Companion"

updateParserInfo :: ParserInfo Command
updateParserInfo = info (pure Update <**> helper)
                   ( fullDesc
                   <> progDesc updateProgDesc
                   <> header vabalHeader
                   )

configureParserInfo :: [String] -> [String] -> ParserInfo Command
configureParserInfo cabalArgs vabalArgs =
    info ((const (Configure cabalArgs vabalArgs) <$> configureArgumentsParser) <**> helper)
    ( fullDesc
    <> header vabalHeader
    <> progDesc configureProgDesc
    )

mainParserInfo :: ParserInfo Command
mainParserInfo =
    info ((Main <$> mainArgumentsParser) <**> helper)
         ( fullDesc
         <> header vabalHeader
         <> progDesc mainProgDesc

         <> footerDoc (Just $ string "Available subcommands:"
                            <> linebreak
                            <> indent 2
                            ( string "vabal update (See vabal update --help)"
                              <> linebreak
                              <> string "vabal configure (See vabal configure --help)"
                            )
                      )
         )

updateExeName :: String -> ParserInfo a -> Bool -> ParserHelp -> ParserHelp
updateExeName name pinfo addTrailingCabalArgs old =
    let p = infoParser pinfo
        desc = maybeToList . unChunk $ fmap (indent 2) (infoProgDesc pinfo)
        usage = if addTrailingCabalArgs then
                    (parserUsage defaultPrefs p name <> string " [-- CABALARGS...]") : desc
                else
                    (parserUsage defaultPrefs p name) : desc
    in old { helpUsage = Chunk . Just $ vcat usage }

parseArgs :: [String] -> IO Command
parseArgs ("update" : args) =
    handleParseResult
    . overFailure (updateExeName "vabal update" updateParserInfo False)
    $ execParserPure defaultPrefs updateParserInfo args

parseArgs ("configure" : args) =
    let (vabalArgs, otherArgs) = break (== "--") args
        cabalArgs = case otherArgs of
                           [] -> []
                           as -> tail as

        parserInfo = configureParserInfo cabalArgs args

    in handleParseResult
       . overFailure (updateExeName "vabal configure" parserInfo True)
       $ execParserPure defaultPrefs parserInfo vabalArgs

parseArgs args = handleParseResult (execParserPure defaultPrefs mainParserInfo args)


main :: IO ()
main = do
    cmd <- getArgs >>= parseArgs

    let errorHandler :: SomeException -> IO ()
        errorHandler ex = do
            writeError $ show ex
            exitWith (ExitFailure 1)

    handle errorHandler $
        case cmd of
            Update -> vabalUpdate
            Main args -> vabalMain args
            Configure cabalArgs args -> vabalConfigure cabalArgs args


