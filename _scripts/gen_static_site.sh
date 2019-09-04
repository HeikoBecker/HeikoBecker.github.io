#!/bin/sh

bundle exec jekyll build -b \/\~hbecker

scp -r _site/* hbecker@contact.mpi-sws.org:~/public_html/
