<img src="https://s3.brnbw.com/icon_512px-512pt-1x-ovTH4eX3VPLxnRKNDA0GZG82nm10oZFML5P00RaGxAl1nnMdKtLhaFFOS4DXsI1ba1V9r2xVukLXoX1JIsDazi48pys3bZNVh3oW.png" width="256" height="256" alt="FlickRing.app" />

**Action ring for your normie mouse.**

Watch the introduction on YouTube:

[![YouTube](https://img.youtube.com/vi/23zQfngkH44/maxresdefault.jpg)](https://www.youtube.com/watch?v=23zQfngkH44&t=3s)

[Download latest version](https://github.com/mikker/FlickRing/releases/latest) or `brew install mikker/tap/flick-ring`

## Behind the scenes

- [Part 1](https://x.com/mikker/status/1829146750990344593)
- [Part 2](https://x.com/mikker/status/1829484136718860775)

## Release

```sh
cp .env.example .env
just distribute
```

Pass `VERSION=1.3.0` to force the next version. Otherwise `just distribute` bumps the patch version, increments the build number, builds + notarizes `FlickRing.app`, uploads `FlickRing.app.zip` to GitHub Releases, updates `CHANGELOG.md`, writes `Updates/appcast.xml`, and updates `../homebrew-tap/Casks/flick-ring.rb`. GitHub Pages publishes the committed `Updates/appcast.xml` at the app's feed URL.

## License

MIT
