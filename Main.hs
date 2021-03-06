module Main where

import Parser
import Expr

import System.Environment
import Text.ParserCombinators.Parsec
import Control.Monad
import Data.List
import Data.Traversable


readStatement :: String -> IO [HStatement]
readStatement input = do
        program <- readFile input
        case parse parseProgram "Olivia" program of
          Left err -> fail $ show err
          Right parsed -> return $ parsed


evalFile :: Env -> String -> IO String
evalFile env expr = do
        x <- readStatement expr
        concat <$> traverse (runIOThrows . liftM show . evalStatement_ env) x


evalExpr :: Env -> String -> IO ()
evalExpr env expr = do
        evalFile env expr
        return ()
                          
run :: String -> IO ()
run expr = nullEnv >>= flip evalExpr expr

main :: IO ()
main = do
        args <- getArgs
        run $ args !! 0

parseProgram :: Parser [HStatement]
parseProgram = spaces *> many (parseStatements <* spaces)
