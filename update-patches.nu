def getfile [ rev: string, file: string] {
  git cat-file blob $"($rev):($file)"
}

export def getversion [ rev: string ] {
  getfile $rev PKGBUILD | lines | parse -r "(?:(?:pkgver)|(?:srcver))=(?<version>[0-9]+.*)" | get 0.version  | str replace -r "(.arch[0-9]+)" ""
}

def getpatches [ rev: string ] {
  git ls-tree --name-only -r $rev | lines | find .patch | reduce --fold [] {|it,acc| $acc ++ {file: $it, hash: $"sha256-(getfile $rev $it | hash sha256 --binary | base64)"}}
}

def main [] {
  jc git log | from json | reverse |reduce --fold {} {|it,acc| $acc | merge {(getversion $it.commit): {commit: $it.commit, patches: (getpatches $it.commit) }} }
}
