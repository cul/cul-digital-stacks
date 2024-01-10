=Digital Stacks Viewer
The code in `.bin` is static site generator for using the [Archival IIIF](https://archival-iiif.github.io/) viewer to
provide access to uploaded static content.

==Generating a Viewer
The generator is invoked from this root directory:
```bash
Usage: ruby .bin/manifest.rb [options]
    -h, --help                       Prints this help
    -b, --base-path [PATH]           Base path to use in links; no PATH arg will be none (default is digitalstacks)
    -d, --domain DOMAIN              Domain name to use in links (default is lito.cul.columbia.edu)
    -p, --port PORT                  TCP port to use in links (default is implicit per ssl option)
    -s, --[no-]ssl                   Build https links (default is true)
    -i, --input-dir INPUT_DIR        Input content directory (required)
    -o, --output-dir OUTPUT_DIR      Output directory (default is 'browser')
```

$INPUT_DIR must be a subdirectory of this root directory. It is typically the bib ID of a licensed collection.
The value for $INPUT_DIR is expected to be a subdirectory of this root directory.

The generator produces a IIIF manifest of the files in the $INPUT_DIR tree and a viewer in an index page under $OUTPUT_DIR. This index page will be in a subdirectory of $OUTPUT_DIR corresponding to the last segment of $INPUT_DIR.

Invoking `ruby .bin/manifest.rb 12345678` will result in a viewer at `browser/12345678/index.html`,
and associated IIIF metadata for the files under `12345678` at `browser/12345678`. The top-level collection manifest
in this case would be at `browser/12345678/collection.json`.

==Local Development
```bash
ruby .bin/manifest.rb -i .fixtures -o test -d localhost -p 8080 --no-ssl -b ""
python3 -m http.server -b localhost 8080
```

Navigate to http://localhost:8080/test/.fixtures in a browser.

==Access Controls
While the manifests are using [IIIF Auth v1](https://iiif.io/api/auth/1.0) login profile to provide a useable UI,
the generated sites rely on .htaccess restricting the token service appropriately.
