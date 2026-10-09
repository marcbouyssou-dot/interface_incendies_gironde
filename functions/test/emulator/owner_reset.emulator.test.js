import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {after, test} from 'node:test';
import {deleteApp as deleteAdminApp, initializeApp as initializeAdminApp} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {deleteApp, initializeApp} from 'firebase/app';
import {
  applyActionCode, connectAuthEmulator, getAuth, sendEmailVerification,
  signInWithEmailAndPassword,
} from 'firebase/auth';
import {connectFirestoreEmulator, doc, getDoc, getFirestore as getClientFirestore} from 'firebase/firestore';
import {claimVerifiedProfessionalIdentity} from '../../src/professional_identity_claims.js';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp({projectId}, 'owner-reset-emulator-test');
const auth = getAdminAuth(adminApp), db = getFirestore(adminApp);
const clients = [];
const password = 'Synthetic-emulator-only-password-42!';
const emails = {a:'owner-a@example.test', b:'owner-b@example.test',
  bridge:'owner-bridge@example.test'};
const legacy = Array.from({length:7}, (_,i)=>`legacy-owner-${process.pid}-${i}`);
const rpps = '80123456789';
const key = 'synthetic-emulator-only-claim-key-1234567890';
const hash = (value) => createHash('sha256').update(JSON.stringify(value)).digest('hex');
let clientNumber=0;
function client() {
  const app=initializeApp({projectId,apiKey:'fake-api-key'},
    `owner-reset-${process.pid}-${++clientNumber}`);
  clients.push(app);
  const instance=getAuth(app);
  connectAuthEmulator(instance,
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`,
    {disableWarnings:true});
  return instance;
}
async function verifyEmail(instance,email) {
  const credential=await signInWithEmailAndPassword(instance,email,password);
  await sendEmailVerification(credential.user);
  const response=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`
    +`/emulator/v1/projects/${projectId}/oobCodes`);
  assert.equal(response.status,200);
  const codes=(await response.json()).oobCodes;
  const code=codes.find((item)=>item.email===email
    && item.requestType==='VERIFY_EMAIL');
  assert.ok(code?.oobCode);
  await applyActionCode(instance,code.oobCode);
  await credential.user.reload();
  assert.equal(credential.user.emailVerified,true);
  return credential.user;
}
async function controlledAdminCount(ids) {
  const snapshots=await db.getAll(...ids.map((id)=>
    db.doc(`platformAdministrators/${id}`)));
  return snapshots.filter((doc)=>doc.exists&&doc.data().active===true).length;
}
async function canReadAdminTerritory(instance) {
  const firestore=getClientFirestore(instance.app);
  connectFirestoreEmulator(firestore,'127.0.0.1',18080);
  return (await getDoc(doc(firestore,'territories/synthetic'))).exists();
}
async function protect() {
  const names=['locations','demoActors','demoEngagements','missions'];
  const result={};
  for(const name of names){
    const docs=(await db.collection(name).get()).docs
      .map((doc)=>({id:doc.id,data:doc.data()}))
      .sort((a,b)=>a.id.localeCompare(b.id));
    result[name]=hash(docs);
  }
  return result;
}
after(async()=>{
  await Promise.all(clients.map((app)=>deleteApp(app)));
  await deleteAdminApp(adminApp);
});

test('synthetic seven-account reset deletes Inondations and keeps Gironde and sites', async()=>{
  assert.equal(process.env.GCLOUD_PROJECT,projectId);
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  const bridgeId=`owner-bridge-${process.pid}`;
  const accountA=`account-a-${process.pid}`;
  const controlled=()=>controlledAdminCount([legacy[0],bridgeId,accountA]);
  // A is deliberately occupied by the sole old Admin; B by another old UID.
  for(let i=0;i<7;i++)await auth.createUser({uid:legacy[i],
    ...(i===0?{email:emails.a,password,emailVerified:true}:{}),
    ...(i===1?{email:emails.b,password,emailVerified:true}:{})});
  await db.doc(`platformAdministrators/${legacy[0]}`).set({uid:legacy[0],active:true});
  for(let i=0;i<3;i++)await db.doc(`roles/${legacy[i]}`).set({role:'responsible'});
  await db.doc(`organizationMemberships/org_${legacy[1]}`).set({uid:legacy[1]});
  for(let i=0;i<5;i++)await db.doc(`volunteers/${legacy[i+1]}`).set({
    uid:legacy[i+1],profession:'physiotherapist',
    ...(i>=2?{rpps,professionalIdType:'rpps',professionalIdValue:rpps,
      verificationStatus:i===4?'unverified':'verified',
      ...(i===4?{}:{verificationSource:'ans_rpps'})}:{})});
  for(let i=0;i<3;i++)await db.doc(`notificationPreferences/${legacy[i]}`)
    .set({uid:legacy[i],compatibleMissions:false});
  for(let i=0;i<9;i++)await db.doc(`pushSubscriptions/old-${i}_${legacy[i%7]}`)
    .set({uid:legacy[i%7],token:`synthetic-token-${i}`,active:false});
  for(let i=0;i<7;i++)await db.doc(`pushTestDispatches/old-${i}_${legacy[0]}`)
    .set({requestedBy:legacy[0],dispatchId:`old-${i}_${legacy[0]}`,
      subscriptionId:`old-${i}_${legacy[0]}`,status:'failed',
      errorCode:'messaging/registration-token-not-registered',
      createdAt:new Date(2026,0,i+1),updatedAt:new Date(2026,0,i+1)});
  await db.doc('operations/synthetic-inondations').set({
    name:'Inondations',status:'planned',createdBy:legacy[0],updatedBy:legacy[0],
  });
  await db.doc('operations/synthetic-gironde').set({name:'Incendies Gironde',
    purpose:'demonstration',status:'completed'});
  await db.doc('territories/synthetic').set({name:'Synthetic territory'});
  for(let i=0;i<65;i++)await db.doc(`locations/site-${i}`).set({name:`Site ${i}`});
  for(let i=0;i<12;i++)await db.doc(`demoActors/actor-${i}`).set({synthetic:true});
  for(let i=0;i<9;i++)await db.doc(`demoEngagements/engagement-${i}`).set({synthetic:true});
  await db.doc('missions/historical').set({operationId:'synthetic-gironde'});
  const protectedBefore=await protect();
  assert.equal(await controlled(),1);

  // Phase 1: delete obsolete test Action and personal failed-push logs.
  await db.doc('operations/synthetic-inondations').delete();
  const oldLogs=(await db.collection('pushTestDispatches').get()).docs;
  assert.equal(oldLogs.length,7);
  assert.ok(oldLogs.every((doc)=>doc.data().status==='failed'
    && doc.data().errorCode==='messaging/registration-token-not-registered'));
  for(const doc of oldLogs)await doc.ref.delete();

  // Phase 2: temporary controlled bridge is mandatory when A holds sole Admin.
  await auth.createUser({uid:bridgeId,email:emails.bridge,password});
  const bridgeClient=client();
  await verifyEmail(bridgeClient,emails.bridge);
  await db.doc(`platformAdministrators/${bridgeId}`).set({uid:bridgeId,active:true});
  assert.equal(await controlled(),2);
  assert.equal(await canReadAdminTerritory(bridgeClient),true);
  await db.doc(`platformAdministrators/${legacy[0]}`).delete();
  await db.doc(`notificationPreferences/${legacy[0]}`).delete();
  await db.doc(`roles/${legacy[0]}`).delete();
  for(const doc of (await db.collection('pushSubscriptions').where('uid','==',legacy[0]).get()).docs)
    await doc.ref.delete();
  assert.equal(await controlled(),1);
  await auth.deleteUser(legacy[0]);
  await auth.createUser({uid:accountA,email:emails.a,password});
  const aClient=client();
  await verifyEmail(aClient,emails.a);
  await db.doc(`platformAdministrators/${accountA}`).set({uid:accountA,active:true});
  assert.equal((await auth.getUser(accountA)).emailVerified,true);
  assert.equal(await controlled(),2);
  assert.equal(await canReadAdminTerritory(aClient),true);
  await db.doc(`platformAdministrators/${bridgeId}`).delete();
  await auth.deleteUser(bridgeId);
  assert.equal(await controlled(),1);

  // Phase 3: remove remaining legacy references, then Auth last per UID.
  for(const name of ['roles','organizationMemberships','volunteers',
    'notificationPreferences','pushSubscriptions']){
    for(const doc of (await db.collection(name).get()).docs){
      if(legacy.some((id)=>doc.ref.path.includes(id)
        || JSON.stringify(doc.data()).includes(id)))await doc.ref.delete();
    }
  }
  assert.equal((await db.collection('pushSubscriptions').get()).size,0);
  assert.equal((await db.collection('volunteers').where('rpps','==',rpps).get()).size,0);
  for(const id of legacy.slice(1))await auth.deleteUser(id);

  // Phase 4/5: create B and claim the verified RPPS atomically.
  const accountB=`account-b-${process.pid}`;
  await auth.createUser({uid:accountB,email:emails.b,password});
  const bClient=client();
  await verifyEmail(bClient,emails.b);
  await db.doc(`volunteers/${accountB}`).set({uid:accountB,
    profession:'physiotherapist',verificationStatus:'unverified'});
  assert.equal(await claimVerifiedProfessionalIdentity({
    firestore:db,uid:accountB,secret:key,
    expectedProfession:'physiotherapist',
    result:{status:'verified',rpps,firstName:'Test',lastName:'EXEMPLE',
      professionCode:'70',professionLabel:'Kinésithérapeute'},
    serverTimestamp:FieldValue.serverTimestamp,
  }),true);
  await db.doc(`notificationPreferences/${accountB}`).set({uid:accountB,
    compatibleMissions:false});
  const bFirestore=getClientFirestore(bClient.app);
  connectFirestoreEmulator(bFirestore,'127.0.0.1',18080);
  assert.equal((await getDoc(doc(bFirestore,`volunteers/${accountB}`))).exists(),true);
  await assert.rejects(()=>getDoc(doc(bFirestore,'territories/synthetic')));

  assert.equal((await db.collection('volunteers').where('rpps','==',rpps).get())
    .docs.filter((doc)=>doc.data().verificationStatus==='verified').length,1);
  assert.equal((await db.collection('pushSubscriptions').get()).size,0);
  assert.equal((await db.collection('pushTestDispatches').get()).size,0);
  assert.equal(await controlled(),1);
  const scenarioUids=new Set([...legacy,bridgeId,accountA,accountB]);
  assert.equal((await auth.listUsers()).users.filter((user)=>
    scenarioUids.has(user.uid)).length,2);
  assert.deepEqual(await protect(),protectedBefore);
  assert.equal((await db.doc('operations/synthetic-inondations').get()).exists,false);
});
