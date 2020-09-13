module Expr where
 
import HParser

import System.Environment
import System.IO
import Prelude hiding (tail)
import Data.IORef
import Control.Applicative hiding ((<|>), many)
import Control.Monad
import Control.Monad.Except
import Text.ParserCombinators.Parsec hiding (spaces)
import Text.ParserCombinators.Parsec.Expr
import Text.ParserCombinators.Parsec.Char hiding (spaces)
import Text.ParserCombinators.Parsec.Language
import qualified Text.ParserCombinators.Parsec.Token as Token
import Data.Char

instance Show HVal where show = showVal
			 
showVal :: HVal -> String
showVal (HString string) = "\"" ++ show string ++ "\""
showVal (HInteger number) = show number
showVal (HBool True) = "True"
showVal (HBool False) = "False"
showVal (HList list) = "[" ++ unravel list ++ "]"
showVal (Expr x op y) = show x ++ " " ++ show op ++ " " ++ show y
showVal (If cond expr expr') = "if (" ++ show cond ++ ")->" ++ show expr++ show expr'
showVal (SubIf cond expr) = "[] (" ++ show cond ++ ")->" ++ show expr
showVal (Do cond expr) = "Do (" ++ show cond ++ ")->" ++ "\n" ++ show expr
showVal (Assign var val) = show var ++ " := " ++ show val ++ "\n"
showVal (Program program) = show program


unravel :: [HVal] -> String
unravel list = unwords (map showVal list)


eval :: HVal -> ThrowsError HVal
---------- EVALUATING PRIMITIVES ----------
eval val@(HString _) = return val
eval val@(HInteger _) = return val
eval val@(HBool _) = return val
eval val@(HList _) = return val
eval (Expr x op y) = return $ evalExpr x op y
eval (Do cond expr) = return $ evalDo cond expr

evalHVal :: HVal -> HVal
evalHVal val@(HString _) = val
evalHVal val@(HInteger _) = val
evalHVal val@(HBool _) = val
evalHVal val@(HList _) = val
evalHVal (Expr x op y) = evalExpr x op y
evalHVal (Do cond expr) = evalDo cond expr

evalDo :: HVal -> HVal -> HVal
evalDo cond expr
  | evalHVal cond == HBool False = expr
  | otherwise = evalDo cond (evalHVal expr)

evalExpr :: HVal -> Op -> HVal -> HVal
----------- Expression Evaulation of Atomic Values ----------
evalExpr (HInteger x) Add (HInteger y)  = HInteger (x + y)
evalExpr (HInteger x) Sub (HInteger y)  = HInteger (x - y)
evalExpr (HInteger x) Mult (HInteger y) = HInteger (x * y)
evalExpr (HInteger x) Div (HInteger y)  = HInteger (x `div` y)
evalExpr (HInteger x) Mod (HInteger y)  = HInteger (x `mod` y)
evalExpr (HInteger x) Greater (HInteger y)   = HBool (x > y)
evalExpr (HInteger x) GreaterEq (HInteger y) = HBool (x >= y)
evalExpr (HInteger x) Less    (HInteger y)   = HBool (x < y)
evalExpr (HInteger x) LessEq  (HInteger y)   = HBool (x <= y)
evalExpr (HInteger x) Equal   (HInteger y)   = HBool (x == y)

evalExpr (HBool x) And (HBool y) = HBool (x && y)
evalExpr (HBool x)    Or      (HBool y)      = HBool (x || y)
evalExpr (HBool x)    Equal   (HBool y)      = HBool (x == y)
----------- Expression Evaulation in Recursive Cases ----------
evalExpr (HInteger x) op (Expr a op' b) = evalExpr (HInteger x) op (evalExpr a op' b)
evalExpr (HBool x)    op (Expr a op' b) = evalExpr (HBool x)    op (evalExpr a op' b)

data HError = NumArgs Integer [HVal]
               | TypeMismatch String HVal
               | Parser ParseError
               | BadSpecialForm String HVal
               | NotFunction String String
               | UnboundVar String String
               | Default String

showError :: HError -> String
showError (UnboundVar message varname)  = message ++ ": " ++ varname
showError (BadSpecialForm message form) = message ++ ": " ++ show form
showError (NotFunction message func)    = message ++ ": " ++ show func
showError (NumArgs expected found)      = "Expected " ++ show expected 
                                       ++ " args; found values " ++ unravel found
showError (TypeMismatch expected found) = "Invalid type: expected " ++ expected
                                       ++ ", found " ++ show found
showError (Parser parseErr)             = "Parse error at " ++ show parseErr

instance Show HError where show = showError

type ThrowsError = Either HError
type IOThrowsError = ExceptT HError IO

trapError action = catchError action (return . show)

extractValue :: ThrowsError a -> a
extractValue (Right val) = val