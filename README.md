# Transport Spider

This is a little Ruby script to generate graphics showing the relationships
between [OpenStreetMap](https://www.openstreetmap.org/) transport / transit
related objects.

## What you need

You need [graphviz](http://www.graphviz.org/) installed, as Transport Spider
uses that to generate PDFs. Transport spider is written in
[Ruby](https://www.ruby-lang.org/en/), so needs that and the package manager
[Bundler](http://bundler.io/) installed.

After that, run `bundle install` in the source directory to complete the
installation.

## How to run it

Type `make`. If you want to use a different
[Overpass](http://wiki.openstreetmap.org/wiki/Overpass_API) server, then set
that using `make OVERPASS_URL=http://localhost/interpreter`, or whatever your
Overpass server is called. Make sure to include the full URL to the interpreter.

## How it works

Each input is a pair of `type,id` which give the OSM type and ID of a station.
For example,
[Paddington Station, London, UK](http://www.openstreetmap.org/way/302026559) is
OSM way number 302026559, so `paddington.input` contains `way,302026559`.

The Transport Spider downloads that, and looks for relations using it which are
part of the
[public transport schema](http://wiki.openstreetmap.org/wiki/Public_transport)
and follows the "web" of connections until it finds transit lines.

More detail on the procedure can be found in the
[blog post](https://mapzen.com/blog/station-relations/).
