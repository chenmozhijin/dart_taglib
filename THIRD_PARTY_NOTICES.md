# Third-Party Notices

`dart_taglib` distributes the following third-party source code or generated
runtime components. The MIT license in [LICENSE](LICENSE) applies only to the
project's own code.

## TagLib 2.3.1

- Project: [TagLib Audio Metadata Library](https://taglib.org/)
- Source: [TagLib v2.3.1](https://github.com/taglib/taglib/releases/tag/v2.3.1)
- Copyright: Scott Wheeler and the contributors listed in
  [third_party/taglib/AUTHORS](third_party/taglib/AUTHORS)
- License: GNU Lesser General Public License version 2.1 or later, or Mozilla
  Public License version 1.1, at the recipient's option
- License texts:
  [COPYING.LGPL](third_party/taglib/COPYING.LGPL) and
  [COPYING.MPL](third_party/taglib/COPYING.MPL)

The complete TagLib source required to rebuild the bundled native and
WebAssembly libraries is included under `third_party/taglib`. The
`dart_taglib` bridge is separate MIT-licensed code.

## utfcpp

- Project: [utfcpp](https://github.com/nemtrif/utfcpp)
- Distribution: bundled by TagLib under `third_party/taglib/3rdparty/utfcpp`
- License: Boost Software License 1.0
- License text:
  [third_party/taglib/3rdparty/utfcpp/LICENSE](third_party/taglib/3rdparty/utfcpp/LICENSE)

## Emscripten

The committed JavaScript and WebAssembly runtime was generated with
Emscripten. Emscripten is available under the MIT and University of
Illinois/NCSA licenses. Its license text, including notices for incorporated
Node.js and musl material, is included in
[LICENSES/EMSCRIPTEN.txt](LICENSES/EMSCRIPTEN.txt).
