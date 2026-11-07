// Sample documents, validation, an index with explain before and after, an aggregation and a KYC query
const d = db.getSiblingDB('vant_nosql');
const h = t => print('\n=== ' + t);
const j = x => print('  ' + JSON.stringify(x));

h('1. Sample documents: the extra fields differ by type');
['DEPOSIT', 'WITHDRAWAL', 'TRANSFER'].forEach(t => j(d.activity.findOne({ type: t, direction: t === 'DEPOSIT' ? 'IN' : 'OUT', amount: { $lt: NumberDecimal('50000') } }, { _id: 0 })));
j(d.kyc.findOne({ tier: 3 }, { _id: 0 }));

h('2. Schema validation rejects bad data');
try { d.activity.insertOne({ customerId: 42, type: 'GIFT', amount: 100, createdAt: new Date() }); print('  accepted'); }
catch (e) { print('  rejected (type GIFT and amount stored as a double): code ' + e.code + ', DocumentValidationFailure'); }

h('3. Index on the feed query: the 5 latest activities of customer 42');
try { d.activity.dropIndex('customerId_1_createdAt_-1'); } catch (e) {}
const feed = () => d.activity.find({ customerId: 42 }).sort({ createdAt: -1 }).limit(5);
function plan(e) {
  const stages = [];
  (function walk(p) { if (!p) return; stages.push(p.stage + (p.indexName ? ' (' + p.indexName + ')' : '')); walk(p.inputStage); })(e.queryPlanner.winningPlan.queryPlan || e.queryPlanner.winningPlan);
  print('  plan: ' + stages.join(' > ') + ' | documents examined: ' + e.executionStats.totalDocsExamined + ' | ' + e.executionStats.executionTimeMillis + ' ms');
}
print('  before the index:'); plan(feed().explain('executionStats'));
d.activity.createIndex({ customerId: 1, createdAt: -1 });
print('  after the index on (customerId, createdAt):'); plan(feed().explain('executionStats'));
feed().forEach(x => j({ type: x.type, amount: x.amount.toString(), at: x.createdAt }));

h('4. Aggregation: total transferred by category, all customers');
d.activity.aggregate([
  { $match: { type: 'TRANSFER', direction: 'OUT' } },
  { $group: { _id: '$category', transfers: { $sum: 1 }, total: { $sum: '$amount' } } },
  { $sort: { total: -1 } },
  { $project: { _id: 0, category: '$_id', transfers: 1, total: { $toString: '$total' } } }]).forEach(j);

h('5. KYC: customers whose selfie liveness score is below 0.85');
const weak = { documents: { $elemMatch: { type: 'SELFIE', livenessScore: { $lt: 0.85 } } } };
print('  matching customers: ' + d.kyc.countDocuments(weak));
d.kyc.find(weak, { _id: 0, customerId: 1, tier: 1, 'documents.type': 1 }).limit(3).forEach(j);

h('6. A transaction delivered twice is stored once (unique index on pgTxnId and customerId)');
const one = d.activity.findOne({ type: 'WITHDRAWAL' }, { _id: 0 });
try { d.activity.insertOne(one); print('  accepted'); } catch (e) { print('  second copy of PostgreSQL transaction ' + one.pgTxnId + ' rejected: code ' + e.code + ' (duplicate key)'); }
