

module Azubi.Syntax where

import Azubi.Model


{-|

Create a state that ensures that a file in @Path@ will
have the content of the String List.

Every String in the List will be a Line in the File.

-}
content :: Path -> [String] -> State
content path fileContent = State [HasFileContent path fileContent]
                                 [FileContent path fileContent]
                                 (Just $ unwords [ "Content for File" , path ])

{-|

Creates a state out of two states.
When the first State fails the second
State will not be checked nor enforced.

This can also be achieved using 'submodule':

@
stateA `requires` stateB == 'submodule' [stateB, stateA]
@

-}
requires :: State -> State -> State
stateA  `requires` stateB = States [] [stateB, stateA] Nothing

{-|

Create a state containing of sub-states,
which have to be fulfilled in order.

If one state is not fulfilled, the following
will be ignored.

-}
submodule :: [State] -> State
submodule states = States [] states Nothing

folderExists :: Path -> State
folderExists path = State [FolderExists path] [CreateFolder path] Nothing



(&) :: [State] -> State -> [State]
states & state = states ++ [state]


-- (!) :: [State] -> State -> [State]
-- states ! state = states ++ [(revertState state)]
