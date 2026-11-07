// Creates the vant_nosql database with validation, loads the KYC documents (generated: PostgreSQL has no KYC table) and creates the activity collection.
// The activity documents come from PostgreSQL through export_activity.sql and mongoimport (see load.sh).
const d = db.getSiblingDB('vant_nosql');
d.dropDatabase();

d.createCollection('activity', { validator: { $jsonSchema: {
  bsonType: 'object',
  required: ['customerId', 'type', 'amount', 'createdAt'],
  properties: {
    customerId: { bsonType: 'number' },
    type: { enum: ['DEPOSIT', 'WITHDRAWAL', 'TRANSFER'] },
    amount: { bsonType: 'decimal' },
    createdAt: { bsonType: 'date' } } } } });

let seed = 42;
const rnd = () => (seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296;
const pick = list => list[Math.floor(rnd() * list.length)];

// the same transaction can be delivered twice (a retry); the unique index keeps one copy
d.activity.createIndex({ pgTxnId: 1, customerId: 1 }, { unique: true });

const kyc = [];
for (let c = 1; c <= 500; c++) {
  const tier = 1 + Math.floor(rnd() * 3);
  const idDoc = pick([{ type: 'BVN', provider: 'NIBSS' }, { type: 'NIN', provider: 'NIMC' }, { type: 'PASSPORT', issuingCountry: 'NG', expiryYear: 2028 + Math.floor(rnd() * 6) }]);
  const documents = [idDoc];
  if (tier >= 2) documents.push({ type: 'SELFIE', livenessScore: Math.round((0.8 + rnd() * 0.2) * 100) / 100 });
  if (tier === 3) documents.push({ type: 'PROOF_OF_ADDRESS', city: 'Lagos' });
  kyc.push({ customerId: c, tier, status: 'VERIFIED', documents });
}
d.kyc.insertMany(kyc);

print('kyc documents:      ' + d.kyc.countDocuments());
