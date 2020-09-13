-- _______________

-- H PROGRAMS
-- _______________
-- k0, k1, ... , k.n := a,b, ... , z
-- ;Do n != N ->
--     k0, k1, ... , k.n := a,b, ... , z
--  Od


-- k0, k1, ... , k.n := a,b, ... , z
-- ;Do n != N ->
--     if P(x) -> f . x
--     [] !P(x) -> !f . x
--     fi
--  Od

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
instance Show HLangVal where show = showVal
type Env = IORef [(String, IORef HLangVal)] 

--------------------------------------------------------------------------------
                      -- Data and Grammar Definitions --
--------------------------------------------------------------------------------

data HLangVal = Atom String
              | String String 
              | Integer Integer
              | Bool Bool
              | Not HLangVal
              | Neg HLangVal
              | List [HLangVal]
              | Seq [HLangVal]
              | Assign String HLangVal
              | If HLangVal HLangVal HLangVal
              | While HLangVal HLangVal
              | Top [HLangVal]
              | Tail [HLangVal]
              | Cons [HLangVal]
              | Skip
              | ABinOp ABinOp
              | RBinOp RBinOp
              | ABinary ABinOp HLangVal HLangVal
              | BBinary BBinOp HLangVal HLangVal
              | RBinary RBinOp HLangVal HLangVal
              | Write HLangVal
               deriving (Read)

data BBinOp = Is | And | Or deriving (Show, Read)

data RBinOp = Greater
            | GEqual
            | Less
            | LEqual
             deriving (Show, Read)

data ABinOp = Add
            | Subtract
            | Multiply
            | Divide
            | Modulo
              deriving (Show, Read)

languageDef =
  emptyDef { Token.commentStart    = "/*"
           , Token.commentEnd      = "*/"
           , Token.commentLine     = "//"
           , Token.identStart      = letter
           , Token.identLetter     = alphaNum
           , Token.reservedNames   = [ "if"
                                     , "fi"
                                     , "then"
                                     , "else"
                                     , "while"
                                     , "do"
                                     , "od"
                                     , "skip"
                                     , "true"
                                     , "false"
                                     , "not"
                                     , "and"
                                     , "or"
                                     , "->"
                                     , "["
                                     , "]"
                                     , "top"
                                     , "tail"
                                     , "cons"
                                     ]
           , Token.reservedOpNames = ["+", "-", "*", "/", "%", ":="
                                      , "<", ">", "and", "or", "not", "="
                                     ]
           }
lexer = Token.makeTokenParser languageDef
identifier = Token.identifier lexer
reserved = Token.reserved lexer
reservedOp = Token.reservedOp lexer
parens = Token.parens lexer
integer = Token.integer lexer
semi = Token.semi lexer
whiteSpace = Token.whiteSpace lexer

--------------------------------------------------
                 -- Parsing  --
--------------------------------------------------
symbol :: Parser Char
symbol = oneOf "!#$%&|*+-/:<=>?@^_~"

spaces :: Parser ()
spaces = skipMany1 space

parseString :: Parser HLangVal
parseString = do
    char '"'
    x <- many (noneOf "\"")
    char '"'
    return $ String x

parseAtom :: Parser HLangVal
parseAtom = do 
              first <- letter
              rest <- many (letter <|> digit)
              let atom = first:rest
              return $ case atom of 
                         "True" -> Bool True
                         "False" -> Bool False
                         "Add" -> ABinOp Add
                         "Subtract" -> ABinOp Subtract
                         "Multiply" -> ABinOp Multiply
                         "Divide" -> ABinOp Divide
                         "Modulo" -> ABinOp Modulo
                         "Greater" -> RBinOp Greater
                         "Less" -> RBinOp Less
                         "GEqual" -> RBinOp GEqual
                         "LEqual" -> RBinOp LEqual
                         _    -> Atom atom

parseBinary :: Parser HLangVal
parseBinary = do    
                    _ <- char '('
                    x <- parseNumber <|> parseString <|> parseAtom
                    op <- oneOf "/*+%-<>gl^|=" 
                    y <- parseNumber <|> parseString <|> parseAtom
                    _ <- char ')'
                    _ <- char '='
                    z <- parseNumber
                    if op == '/' then 
                            return $ BBinary Is (ABinary Divide x y) z 
                    else
                            return $ String "Error"
             <|>
              do
                    x <- parseNumber <|> parseString <|> parseAtom
                    op <- oneOf "/*+%-<>gl^|=" 
                    y <- parseNumber <|> parseString <|> parseAtom
                    if op == '*' then 
                            return $ ABinary Multiply x y 
                    else
                        if op == '/' then
                            return $ ABinary Divide x y 
                        else 
                            if op == '%' then
                                return $ ABinary Modulo x y
                            else
                                if op == '+' then
                                    return $ ABinary Add x y
                                else 
                                    if op == '-' then 
                                        return $ ABinary Subtract x y
                                    else
                                        if op == '<' then
                                            return $ RBinary Less x y
                                        else
                                            if op == '>' then
                                                return $ RBinary Greater x y
                                            else
                                                if op == 'l' then
                                                    return $ RBinary LEqual x y
                                                else
                                                    if op == 'g' then
                                                        return $ RBinary GEqual x y
                                                    else
                                                        if op == '^' then
                                                            return $ BBinary And x y
                                                        else
                                                            if op == '|' then
                                                                return $ BBinary Or x y
                                                            else
                                                                if op == '=' then
                                                                    return $ BBinary Is x y
                                                                else
                                                                    return $ String "Error"    

                                                                  
parseNumber :: Parser HLangVal
parseNumber = liftM (Integer . read) $ many1 digit

parseList :: Parser HLangVal
parseList = liftM List $ sepBy parseExpr spaces

statement :: Parser HLangVal
statement =   parens statement
          <|> sequenceOfStmt

sequenceOfStmt =
  do list <- (sepBy1 statement' semi)
     return $ if length list == 1 then head list else Seq list


hLangParser :: Parser HLangVal
hLangParser = whiteSpace >> statement


statement' :: Parser HLangVal
statement' =   ifStmt
           <|> whileStmt
           <|> skipStmt
           <|> assignStmt
           <|> listStmt
           
parseExpr :: Parser HLangVal   
parseExpr =   hLangParser
          <|> parseAtom
          <|> parseNumber 
          <|> parseString
          <|> parseWrite
          <|> do 
                _ <- char '['
                x <- try parseList                    
                _ <- char ']'
                return x
          <|> do 
                _ <- char '('
                x <- try parseBinary
                _ <- char ')'
                return x
    
listStmt :: Parser HLangVal
listStmt = 
    do reserved "top"
       _ <- char '['
       x <- try parseList
       _ <- char ']'
       return $ Top [x]
    <|>
    do reserved "tail"
       _ <- char '['
       x <- try parseList
       _ <- char ']'
       return $ Tail [x]
    <|>
    do reserved "cons"
       _ <- char '['
       x <- try parseList
       _ <- char ']'
       _ <- char ' '
       _ <- char '['
       y <- try parseList
       _ <- char ']'
       return $ Cons [x, y]

parseWrite :: Parser HLangVal
parseWrite =
    do
        _ <- string "write"
        _ <- char '('
        x <- parseAtom <|> parseNumber <|> parseList <|> parseString
        _ <- char ')'
        return $ Write x
       
ifStmt :: Parser HLangVal
ifStmt =
  do 
     _ <- string "if "
     cond  <- do _ <- char '('
                 x <- try parseBinary
                 _ <- char ')'
                 _ <- string "-> "
                 return x
     stmt1 <- statement
     spaces
     _ <- string "[] "
     aond  <- do _ <- char '('
                 y <- try parseBinary
                 _ <- char ')'
                 _ <- string "-> "
                 return y
     stmt2 <- statement
     spaces
     _ <- string "fi"
     return $ If cond stmt1 stmt2

whileStmt :: Parser HLangVal
whileStmt =
  do _ <- string "Do "
     cond  <- do 
                _ <- char '('
                x <- try parseBinary
                _ <- char ')'
                _ <- string "->" <|> string "-> "
                return x
     spaces
     stmt <- statement <|>
             do 
                _ <- char '('
                x <- try parseBinary
                _ <- char ')'
                return x
     spaces
     _ <- string "Od"
     return $ While cond stmt

assignStmt :: Parser HLangVal
assignStmt =
  do var  <- identifier
     _ <- string ":="
     expr <- do 
                _ <- char '('
                x <- try parseBinary
                _ <- char ')'
                return x
            <|>
            do
                _ <- char '['
                x <- try parseList
                _ <- char ']'
                return x
            <|>
                parseNumber
            <|>
                parseString
             
     return $ Assign var expr

skipStmt :: Parser HLangVal
skipStmt = reserved "skip" >> return Skip

parseFile :: String -> IO HLangVal
parseFile file =
  do program  <- readFile file
     case parse hLangParser "" program of
       Left e  -> print e >> fail "parse error"
       Right r -> return r

--------------------------------------------------
                -- Evaluation --
--------------------------------------------------

showVal :: HLangVal -> String
showVal (Atom contents) = show contents
showVal (String contents) = "\"" ++ contents ++ "\""
showVal (Integer contents) = show contents
showVal (Neg contents) = "-" ++ show contents
showVal (Bool True) = "True"
showVal (Bool False) = "False"
showVal (Not contents) = "Not " ++ show contents
showVal (List contents) = "[" ++ unwordsList contents ++ "]"
showVal (Seq contents) = unwordsList contents
showVal (Assign var val) = var ++ " := " ++ show val
showVal (If cond stmt1 stmt2) = "if " ++ show cond ++ " then " ++ show stmt1 ++ " else " ++ show stmt2 
showVal (While cond stmt) = ";Do " ++ show cond ++ " -> " ++ show stmt ++ " Od"
showVal (Skip) = "Skip"
showVal (ABinary op x y) = show x ++ " " ++ show op ++ " " ++ show y 
showVal (BBinary op x y) = show x ++ " " ++ show op ++ " " ++ show y 
showVal (RBinary op x y) = show x ++ " " ++ show op ++ " " ++ show y 
showVal (ABinOp op) = show op
showVal (RBinOp op) = show op

unwordsList :: [HLangVal] -> String
unwordsList = unwords . map showVal

top :: Env -> [HLangVal] -> IOThrowsError HLangVal
top env [List (x : xs)] = return x
top env [badArg]                = throwError $ TypeMismatch "pair" badArg
top env badArgList              = throwError $ NumArgs 1 badArgList

tail :: Env -> [HLangVal] -> IOThrowsError HLangVal
tail env [List (x : xs)] = return $ List xs
tail env [badArg]                = throwError $ TypeMismatch "pair" badArg
tail env badArgList              = throwError $ NumArgs 1 badArgList


cons :: Env -> [HLangVal] ->  IOThrowsError HLangVal
cons env [List xs, List []] = return $ List $ xs
cons env [List xs, List ys] = return $ List $ xs ++ ys


evalABinOp :: Env -> HLangVal -> ABinOp -> HLangVal -> IOThrowsError HLangVal
evalABinOp env (Integer a) Add (Integer b)   = return $ Integer $ a + b
evalABinOp env (Integer a) Subtract (Integer b)   = return $ Integer $ a - b
evalABinOp env (Integer a) Multiply (Integer b)   = return $ Integer $ a * b
evalABinOp env (Integer a) Divide (Integer b)   = return $ Integer $ a `div` b
evalABinOp env (Integer a) Modulo (Integer b)   = return $ Integer $ a `mod` b
evalABinOp env (Atom a)    op  b@(Integer _) = getVar env a >>= (\c -> evalABinOp env c op b)
evalABinOp env a@(Integer _)    op  (Atom b) = getVar env b >>= (\c -> evalABinOp env a op c)
evalABinOp env (Atom a)    op (Atom b) = getVar env a >>= (\c -> getVar env b >>= (\d -> evalABinOp env c op d))

evalBBinOp :: Env -> HLangVal -> BBinOp -> HLangVal -> IOThrowsError HLangVal
evalBBinOp env (Bool a) And (Bool b) = return $ Bool (a && b)
evalBBinOp env (Bool a) And (Not (Bool b)) = return $ Bool (a && b)
evalBBinOp env (Not (Bool a)) And (Bool b) = return $ Bool (a && b)
evalBBinOp env (Not (Bool a)) And (Not (Bool b)) = return $ Bool (a && b)
evalBBinOp env (Bool a) Or (Bool b) = return $ Bool (a || b)
evalBBinOp env (Bool a) Or (Not (Bool b)) = return $ Bool (a || b)
evalBBinOp env (Not (Bool a)) Or (Bool b) = return $ Bool (a || b)
evalBBinOp env (Not (Bool a)) Or (Not (Bool b)) = return $ Bool (a || b)
evalBBinOp env (Integer a) Is (Integer b) = return $ Bool (a == b)
evalBBinOp env (ABinary op x y) Is (Integer b) = (eval env (ABinary op x y)) >>= (\a -> (evalBBinOp env a) Is (Integer b))
evalBBinOp env (Atom a)    op  b@(Bool _) = getVar env a >>= (\c -> evalBBinOp env c op b)
evalBBinOp env a@(Bool _)    op  (Atom b) = getVar env b >>= (\c -> evalBBinOp env a op c)
evalBBinOp env (Atom a)    op (Atom b) = getVar env a >>= (\c -> getVar env b >>= (\d -> evalBBinOp env c op d))

evalRBinOp :: Env -> HLangVal -> RBinOp -> HLangVal -> IOThrowsError HLangVal
evalRBinOp env (Integer a) Greater (Integer b) = return $ Bool (a > b)
evalRBinOp env (Integer a) Less (Integer b) = return $ Bool (a < b)
evalRBinOp env (Integer a) GEqual (Integer b) = return $ Bool (a >= b)
evalRBinOp env (Integer a) LEqual (Integer b) = return $ Bool (a <= b)
evalRBinOp env (Atom a)    op  b@(Integer _) = getVar env a >>= (\c -> evalRBinOp env c op b)
evalRBinOp env a@(Integer _) op  (Atom b) = getVar env b >>= (\c -> evalRBinOp env a op c)
-- evalRBinOp env (RBinary op x y) Is (Integer b) = (eval env (RBinary op x y)) >>= (\a -> (evalRBinOp env a) Is (Integer b))
evalRBinOp env (Atom a)    op (Atom b) = getVar env a >>= (\c -> getVar env b >>= (\d -> evalRBinOp env c op d))

hLangBool2Bool :: Env -> HLangVal -> Bool
hLangBool2Bool env (Bool True) = True
hLangBool2Bool env (Bool False) = False
hLangBool2Bool env (String "True") = True
hLangBool2Bool env (String "False") = False
hLangBool2Bool env (Atom "True") = True
hLangBool2Bool env (Atom []) = False
hLangBool2Bool env (Atom ['T']) = True
hLangBool2Bool env (Atom (p:_)) = if p == 'T' then True else False
hLangBool2Bool env (Atom ['T', 'r']) = False
hLangBool2Bool env (Atom ('T':'r':p:_)) = True
hLangBool2Bool env (String []) = False
hLangBool2Bool env (String (p:_)) = True
hLangBool2Bool env (String ['F']) = False
hLangBool2Bool env (String ('F':p:_)) = False
hLangBool2Bool env val@(Integer _) = True
hLangBool2Bool env (List []) = False
hLangBool2Bool env (List [x]) = True
hLangBool2Bool env (List (_:_:_)) = True
hLangBool2Bool env (Seq _) = True
-- hLangBool2Bool env (ABinary op x y) = hLangBool2Bool (evalABinOp env x op y)


-- evalWhile :: Env -> HLangVal -> HLangVal -> IOThrowsError HLangVal
-- evalWhile env cond stmt = eval env stmt >>= (\c -> do
--                                                      s <- eval env cond
--                                                      if (hLangBool2Bool env s) == False
--                                                          then return $ c
--                                                             else eval env (While cond stmt))
evalWhile :: Env -> HLangVal -> HLangVal -> IOThrowsError HLangVal
evalWhile env cond stmt = if (hLangBool2Bool env cond) == False then return $ stmt else eval env (While cond (stmt))



evalWrite :: Env -> HLangVal -> IOThrowsError HLangVal
evalWrite env x = return $ x


eval :: Env -> HLangVal -> IOThrowsError HLangVal
eval env val@(Atom _) = return val
eval env val@(String _) = return val
eval env val@(Integer _) = return val
eval env val@(Bool _) = return val
eval env val@(Neg _) = return val
eval env val@(Not _) = return val
eval env (List [Atom "quote", val]) = return val
eval env (Assign var val) = eval env val >>= defineVar env var
eval env (List [Atom "set!", Atom var, form]) =
     eval env form >>= setVar env var
eval env (Seq [Atom "define", Atom var, form]) =
     eval env form >>= defineVar env var
eval env val@(List _) = return val
eval env (Top xs) = top env xs
eval env (Tail xs) = tail env xs
eval env (Cons xs) = cons env xs
eval env val@(Seq _) = return val
eval env (If cond x y) = eval env cond >>= (\c -> if (hLangBool2Bool env c) then (eval env x) else (eval env y))         
eval env (While cond stmt) = evalWhile env cond stmt                                                                                                  
eval env val@(ABinOp _) = return val
eval env val@(RBinOp _) = return val
eval env (ABinary op x y) = evalABinOp env x op y
eval env (BBinary op x y) = evalBBinOp env x op y
eval env (RBinary op x y) = evalRBinOp env x op y
eval env (Write x) = return x

readExpr :: String -> ThrowsError HLangVal
readExpr input = case parse parseExpr "H" input of
    Left err -> throwError $ Parser err
    Right val -> return val






-------------------------------------
          -- REPL AND MAIN --
-------------------------------------

evalAndPrint :: Env -> String -> IO ()
evalAndPrint env expr =  evalString env expr >>= putStrLn

evalString :: Env -> String -> IO String
evalString env expr = runIOThrows $ liftM show $ (liftThrows $ readExpr expr) >>= eval env

runOne :: String -> IO ()
runOne expr = nullEnv >>= flip evalAndPrint expr

runRepl :: IO ()
runRepl = nullEnv >>= until_ (== "quit") (readPrompt "H> ") . evalAndPrint

readPrompt :: String -> IO String
readPrompt prompt = flushStr prompt >> f 1 ""

getLineFoo :: IO String
getLineFoo = do
                x <- getLine
                y <- getLine
                z <- getLine
                return (x++y++z)

getDepth :: Char -> Int
getDepth 'i' = 2
getDepth 'D' = 2
getDepth '<' = 0
getDepth '>' = 0
getDepth '[' = 0
getDepth ']' = 0
getDepth 'O' = 0
getDepth _ = 0

f :: Int -> String -> IO String
f n s
  | n == 0 = do
                x <- getLine
                return $ (s ++ x)
  | otherwise = do
                    x <- getLine
                    let m = n + (getDepth (head (dropWhile isSpace x)))
                    f (m - 1) (s ++ x)

flushStr :: String -> IO ()
flushStr str = putStr str >> hFlush stdout

until_ :: Monad m => (a -> Bool) -> m a -> (a -> m ()) -> m ()
until_ pred prompt action = do 
   result <- prompt
   if pred result 
      then return ()
      else action result >> until_ pred prompt action

main :: IO ()
main = do args <- getArgs
          case length args of
               0 -> runRepl
               1 -> runOne $ args !! 0
               otherwise -> putStrLn "Program takes only 0 or 1 argument"







------------------------------------------------------------
                -- Variable Assignment --
------------------------------------------------------------

nullEnv :: IO Env
nullEnv = newIORef []

liftThrows :: ThrowsError a -> IOThrowsError a
liftThrows (Left err) = throwError err
liftThrows (Right val) = return val

runIOThrows :: IOThrowsError String -> IO String
runIOThrows action = runExceptT (trapError action) >>= return . extractValue

isBound :: Env -> String -> IO Bool
isBound envRef var = readIORef envRef >>= return . maybe False (const True) . lookup var

getVar :: Env -> String -> IOThrowsError HLangVal
getVar envRef var  =  do env <- liftIO $ readIORef envRef
                         maybe (throwError $ UnboundVar "Getting an unbound variable" var)
                               (liftIO . readIORef)
                               (lookup var env)

setVar :: Env -> String -> HLangVal -> IOThrowsError HLangVal
setVar envRef var value = do env <- liftIO $ readIORef envRef
                             maybe (throwError $ UnboundVar "Setting an unbound variable" var)
                                   (liftIO . (flip writeIORef value))
                                   (lookup var env)
                             return value

defineVar :: Env -> String -> HLangVal -> IOThrowsError HLangVal
defineVar envRef var value = do
     alreadyDefined <- liftIO $ isBound envRef var
     if alreadyDefined
        then setVar envRef var value >> return value
        else liftIO $ do
             valueRef <- newIORef value
             env <- readIORef envRef
             writeIORef envRef ((var, valueRef) : env)
             return value

bindVars :: Env -> [(String, HLangVal)] -> IO Env
bindVars envRef bindings = readIORef envRef >>= extendEnv bindings >>= newIORef
     where extendEnv bindings env = liftM (++ env) (mapM addBinding bindings)
           addBinding (var, value) = do ref <- newIORef value
                                        return (var, ref)






--------------------------------------------------
                -- Error Handling --
--------------------------------------------------

data HLangError = NumArgs Integer [HLangVal]
               | TypeMismatch String HLangVal
               | Parser ParseError
               | BadSpecialForm String HLangVal
               | NotFunction String String
               | UnboundVar String String
               | Default String

showError :: HLangError -> String
showError (UnboundVar message varname)  = message ++ ": " ++ varname
showError (BadSpecialForm message form) = message ++ ": " ++ show form
showError (NotFunction message func)    = message ++ ": " ++ show func
showError (NumArgs expected found)      = "Expected " ++ show expected 
                                       ++ " args; found values " ++ unwordsList found
showError (TypeMismatch expected found) = "Invalid type: expected " ++ expected
                                       ++ ", found " ++ show found
showError (Parser parseErr)             = "Parse error at " ++ show parseErr

instance Show HLangError where show = showError

type ThrowsError = Either HLangError
type IOThrowsError = ExceptT HLangError IO

trapError action = catchError action (return . show)

extractValue :: ThrowsError a -> a
extractValue (Right val) = val