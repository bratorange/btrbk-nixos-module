with builtins;
{
  list2lines =
    inputList: (concatStringsSep "\n" inputList) + "\n";

  lines2list =
    inputLines: if inputLines==null then [] else
    filter isString (split "\n" inputLines);

  addPrefixes =
    lines: map (line: "  " + line) lines;
}
