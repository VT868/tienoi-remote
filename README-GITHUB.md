# TienOi GitHub Feed

App supports a remote partner feed so partner order, text, limits, and affiliate links can be changed without submitting a new App Store build.

## Files for GitHub Pages

- `docs/partners.json`: production partner feed.
- `docs/logos/`: partner logo files for future remote image hosting.

## Publish With GitHub Pages

1. Create a public GitHub repository, for example `tienoi-remote`.
2. Push this project to the repository.
3. Open GitHub repository settings.
4. Go to `Pages`.
5. Select `Deploy from a branch`.
6. Select branch `main` and folder `/docs`.
7. GitHub will publish the feed at:

```text
https://<github-username>.github.io/tienoi-remote/partners.json
```

8. Replace `feedURL` in `TienOi/ContentView.swift` with that URL before the App Store build.

## Partner Logo Fields

Use `logoAsset` for bundled logos already inside the app:

```json
"logoAsset": "PartnerVayVND"
```

After GitHub Pages is enabled, you may use `logoURL` for remote logos:

```json
"logoURL": "https://<github-username>.github.io/tienoi-remote/logos/vayvnd.png"
```

Keep the feed transparent and consistent with the app description. Do not use the remote JSON to introduce hidden app behavior or misleading loan claims.
