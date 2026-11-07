#!/usr/bin/env bash
# Exports the activity from PostgreSQL, creates the MongoDB collections and loads everything.
set -e
cd "$(dirname "$0")"
mkdir -p data
psql -d vant_personal -q -f Dele-Adelusi_Oluwanisola_301910982_export_activity.sql
docker exec vant-mongo mongosh --quiet vant_nosql /work/Dele-Adelusi_Oluwanisola_301910982_load.js
docker exec vant-mongo mongoimport --quiet --db vant_nosql --collection activity --file /work/data/activity.jsonl
docker exec vant-mongo mongosh --quiet vant_nosql --eval 'print("activity documents: " + db.activity.countDocuments())'
