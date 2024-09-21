sharableDir := '../sharablesUpdater'
sharableOutputFile := `pwd` / 'data' / 'sharables.json'

build: update-sharables
  @hugo

clean:
  @rm -rf ./public

update-sharables:
  #!/usr/bin/env bash
  cd {{sharableDir}}
  .venv/bin/python3 -m main
  cp sharables.json {{sharableOutputFile}}
