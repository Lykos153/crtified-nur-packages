#!/usr/bin/env nu

def getfile [ rev: string, file: string] {
  git cat-file blob $"($rev):($file)"
}

def getversion [ rev: string ] {
  getfile $rev PKGBUILD | lines | parse -r "(?:(?:pkgver)|(?:srcver))=(?<version>[0-9]+.*)" | get 0.version  | str replace -r "(.arch[0-9]+)" ""
}

def getpatches [ rev: string ] {
  let url_template = "https://aur.archlinux.org/cgit/aur.git/plain/%FILE%?h=linux-vfio&id=%COMMIT%"
  git ls-tree --name-only -r $rev | lines | find .patch | reduce --fold [] {|it,acc|
    let hash = $"sha256-(getfile $rev $it | hash sha256 --binary | base64)"
    let url = $url_template | str replace "%COMMIT%" $rev | str replace "%FILE%" $it
    $acc ++ {file: $it, hash: $hash, url: $url }
  }
}

def main [--output (-o): string] {
  let cwd = (pwd)
  let dir = (mktemp -d)
  cd $dir
  git clone https://aur.archlinux.org/linux-vfio.git .
  let log_sorted = jc git log | from json | reverse
  let result = $log_sorted | reduce --fold {} {|it,acc| 
    let version = (getversion $it.commit)
    print $"Found version ($version) \t in ($it.commit) (($acc | columns | length) + 1)/~($log_sorted | length)"
    $acc | merge {$version: {commit: $it.commit, patches: (getpatches $it.commit) }}
  }
  cd $cwd
  rm -rf $dir

  if $output != "" {
    $result | to json | save --force $output
    print $"Stored result in ($output)"
  } else {
    $result
  }
}
