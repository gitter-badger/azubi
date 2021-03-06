
module Azubi.Render.BashScript( bashScriptExecuter
                              , bashScriptGenerator) where

import Azubi.Core.Command
import Azubi.Core.Provision
import Azubi.Render.Warez

--
-- This is a small renderer
-- which compiles the wishlist into a shell-script
--
bashScriptExecuter :: UserContext -> [Command] -> String
bashScriptExecuter context commands =
  unlines $
  scripHeader
  ++ printLogo
  ++ (bashScriptGenerator context commands)
  where
    scripHeader = [ "#!/bin/bash"
                  , "#"
                  , "# script is automatically generated by "
                  ]
    printLogo = ["cat <<EOF"]
      ++ azubiLogo
      ++ ["EOF"]

bashScriptGenerator :: UserContext -> [Command] -> [String]
bashScriptGenerator context commands =
    (bashScriptInit context)
    ++ (concat (map (commandSnippet $ BashScriptContext [] context) commands))


bashScriptInit :: UserContext -> [String]
bashScriptInit Root = [ "if [[ `whoami` != root ]]; then"
                  , "  echo 'you must be root to run this script !'"
                  , "  exit 1"
                  , "fi"
                  , "" ]
bashScriptInit _ = []

data BashScriptContext = BashScriptContext { dependencyStack :: [String]
                                           , renderContext :: UserContext
                                           }


commandSnippet :: BashScriptContext -> Command -> [ String ]

commandSnippet context (ShellCommand command) =
  [ command ++ " &>> ~/.azubi.log"
  , "if [[ $? -ne 0 ]]; then"
  , "echo 'Error : running `" ++ command ++ "`' failed | tee -a ~/.azubi.log"
  ]
  ++ [ d ++ "=false"  | d <- (dependencyStack context) ]
  ++ ["fi"]

commandSnippet context@(BashScriptContext _ Root)(SuperUserShellCommand command) =
  commandSnippet context (ShellCommand command)

commandSnippet context@(BashScriptContext _ (User None))  (SuperUserShellCommand command) =
  commandSnippet context (InfoMsg $ "cant run superuser command `" ++ command ++ "` as Normal user")

commandSnippet context@(BashScriptContext _ (User Sudo))  (SuperUserShellCommand command) =
  concat $ map (\c -> commandSnippet context c) commands
  where
    commands = [ InfoMsg $ "sudo \"" ++  command ++ "\""
               , ShellCommand $ "sudo \"" ++ command ++"\""]

commandSnippet context@(BashScriptContext _ (User Su))  (SuperUserShellCommand command) =
  concat $ map (\c -> commandSnippet context c) commands
  where
    commands = [ InfoMsg $ "su - -c \"" ++  command ++ "\""
               , ShellCommand $ "su - -c \"" ++ command ++"\""]

commandSnippet _ (InfoMsg i) =
  ["echo 'INFO : " ++ i ++ "' | tee -a ~/.azubi.log" ]

commandSnippet _ (ErrorMsg i) =
  ["echo 'ERROR: " ++ i ++ "' | tee -a ~/.azubi.log" ]

commandSnippet _ (LogMsg i) =
  ["echo 'INFO : " ++ i ++ "' &>> ~/.azubi.log"]

commandSnippet context (IfCommand (BoolCommand b) t e) =
    ["if [[ " ++ b ++ " ]]; then" ]
    ++ thenPart t
    ++ elsePart e
    ++ ["fi"]
  where
    thenPart [] = ["echo -n ''"]
    thenPart commands = bodyIndent (map (commandSnippet context) commands)
    elsePart [] = []
    elsePart commands = ["else" ]
      ++ bodyIndent (map (commandSnippet context) commands)


commandSnippet _ (FileContent contentPath content) =
  [ "cat >" ++ contentPath ++ " <<EOF" ]
  ++ content
  ++ ["EOF"]

commandSnippet context (Dependency [] []) = []

commandSnippet context (Dependency [] dependency) =
  concat (map (commandSnippet context) dependency)

commandSnippet context (Dependency body []) =
  concat (map (commandSnippet context) body)

commandSnippet context (Dependency body dependency) =
  [ dependencyVariable ++ "=true" ]
  ++ concat (map (commandSnippet (BashScriptContext (dependencyVariable : (dependencyStack context)) (renderContext context ) ) ) dependency)
  ++ ["if $" ++ dependencyVariable ++ " ; then"]
  ++ bodyIndent (map (commandSnippet context) body)
  ++ ["fi"]
  where
    dependencyVariable :: String
    dependencyVariable = "dependency" ++ (show $ length $ dependencyStack context )


bodyIndent :: [[String]] -> [ String ]
bodyIndent body =
  concat body
