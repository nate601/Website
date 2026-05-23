sharableDir := '../sharablesUpdater'
sharableOutputFile := `pwd` / 'data' / 'sharables.json'
completedBooksOutputFile := `pwd` / 'data' / 'completedBooks.json'
websiteDir := `pwd`

build: update-sharables
  @hugo

clean:
  @rm -rf ./public

update-sharables:
  #!/usr/bin/env bash
  cd {{sharableDir}}
  .venv/bin/python3 -m main
  cp sharables.json {{sharableOutputFile}}
  cp completedBooks.json {{completedBooksOutputFile}}
  exit 0

update-and-push-sharables: unsaved-changes-stash update-sharables && unsaved-changes-pop
  #!/usr/bin/env bash
  cd {{websiteDir}}
  git add {{sharableOutputFile}}
  git commit -a -m "Update-Sharables {{datetime('%F')}}"
  git push
  
unsaved-changes-stash:
  #!/usr/bin/env bash
  cd {{websiteDir}}
  git stash
  exit 0
unsaved-changes-pop:
  #!/usr/bin/env bash
  cd {{websiteDir}}
  git stash pop
  exit 0




