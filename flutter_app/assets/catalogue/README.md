# Packaged starting catalogue

`initial_catalogue.json` is generated from the Mac's SQLite database by
`scripts/package_catalogue.py`. It is deliberately ignored by Git. The mobile and
TestFlight build scripts refresh it before building. It includes restaurant
records and saved review evidence, but no pairing credentials. Existing device
copies and unsynced edits are never replaced by this starting snapshot on upgrade.
