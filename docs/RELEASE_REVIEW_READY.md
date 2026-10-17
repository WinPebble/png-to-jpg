# v2 Store candidate — review checkpoint, 2026-10-17

PR: https://github.com/WinPebble/png-to-jpg/pull/1

The reviewed branch candidate has passed core/shell quality, package validation,
full local WACK (all required tests PASS, one documented optional CreateProcessW
finding) and signed local install/update/uninstall. See Gate B/C/D, WACK and
signed-deployment records for exact tested hashes and limitations.

The native core, shell implementation, compiled resources, artwork, package
manifests/identity and CMake configuration are unchanged from the WACK-reviewed
payload source `5fe39357385874ffb53e7fc9347b93b48f7ffead`. Subsequent changes
improve test runners and document results/listing preparation. Current v1 source
under `src/` is unchanged against main and the `v1.0.0` tag is retained.

Prepared listing defaults: free, Utilities + tools, English (en-US), all available
markets, PNG to JPG GitHub Issues support, app-specific privacy policy. Actual
Partner Center forms, age-rating answers, screenshots and release options still
need review. No other product's release authorization applies to this app.

## Next sequence after separate merge confirmation

1. Merge the reviewed PR into main without changing the historical v1 tag/release.
2. Dispatch `build-msix-store.yml` explicitly on main; it supports manual dispatch
   but currently does not trigger on a main push. Verify the returned run's actual
   head commit matches the merged main commit before downloading artifacts.
3. Keep the unsigned full-MSIX output, source commit, provenance and SHA-256
   evidence together. Local self-signed deployment clones are never uploaded.
   Store package/file version stays 2.0.0.0; current ProductVersion remains
   2.0.0-rc.1 until a separately reviewed metadata change. No released v2 tag exists.
4. Revalidate the actual main-build package and review any payload differences.
   Collect genuine product screenshots with that package; retain truthful local
   test versus Store-delivery distinctions. Verify the main privacy URL resolves.
5. Present the exact main package hash, screenshots, listing, capability notes and
   release settings for separate upload/submission approval. Do not enable
   automatic publication by inference from the worldwide audience recommendation.

This checkpoint authorizes no merge, upload, certification request or publication.
