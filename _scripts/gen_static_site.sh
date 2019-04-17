#!/bin/sh

echo "  <div class="divider">
  </div>
  <div class="row">
    <a href="https://data-protection.mpi-klsb.mpg.de/sws/people/hbecker">Data Protection</a>
    <a href="https://imprint.mpi-klsb.mpg.de/sws/people/hbecker">Imprint</a>
  </div>" >> ./_includes/main.html

bundle exec jekyll build

for num in 1 2 3 4 5 6
do
    sed '$d' -i _includes/main.html
done
#head -n -6 ./_includes/main.html > ./_includes/main.html
