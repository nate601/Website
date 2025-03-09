sharableDir := '../sharablesUpdater'
sharableOutputFile := `pwd` / 'data' / 'sharables.json'

build: update-sharables
  @hugo

clean:
  @rm -rf ./public

update-sharables:
  #!/usr/bin/env bash
  git stash
  cd {{sharableDir}}
  .venv/bin/python3 -m main
  cp sharables.json {{sharableOutputFile}}
  cd `pwd`
  git add {{sharableOutputFile}}
  git commit -a -m "Update-Sharables {{datetime('%F')}}"
  git push
  git stash pop
  
