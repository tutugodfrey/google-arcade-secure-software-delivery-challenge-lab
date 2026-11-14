# Secure Software Delivery: Challenge Lab

[Secure Software Delivery: Challenge Lab](https://www.skills.google/games/7566/labs/46184)


```bash
export REGION=us-east4
export PROJECT_ID=qwiklabs-gcp-01-4a14e3b7cf5c

gcloud services enable   cloudkms.googleapis.com   run.googleapis.com   cloudbuild.googleapis.com   container.googleapis.com   containerregistry.googleapis.com   artifactregistry.googleapis.com   containerscanning.googleapis.com   ondemandscanning.googleapis.com   binaryauthorization.googleapis.com

mkdir sample-app && cd sample-app
gcloud storage cp gs://spls/gsp521/* .
gcloud artifacts repositories create artifact-scanning-repo --location=$REGION --repository-format=docker --description="Scanning Repo"
gcloud artifacts repositories create artifact-prod-repo --location $REGION --repository-format=docker --description="Prod repo"

export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)');
echo $PROJECT_NUMBER 


gcloud builds submit . --config=cloudbuild.yaml
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)');
echo $PROJECT_NUMBER


cat > ./vulnerability_note.json << EOM
{
  "attestation": {
   "hint": {
      "human_readable_name": "Container Vulnerabilities attestation authority"
    }
  }
}
EOM


export NOTE_ID=vulnerability_note
curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $(gcloud auth print-access-token)" --data-binary @./vulnerability_note.json "https://containeranalysis.googleapis.com/v1/projects/$PROJECT_ID/notes/?noteId=$NOTE_ID"
curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $(gcloud auth print-access-token)"  "https://containeranalysis.googleapis.com/v1/projects/$PROJECT_ID/notes/$NOTE_ID"

export ATTESTOR_ID=vulnerability-attestor
gcloud container binauthz attestors create $ATTESTOR_ID --attestation-authority-note=$NOTE_ID --attestation-authority-note-project=$PROJECT_ID
gcloud container binauthz attestors list --project=$PROJECT_ID
export BINAUTHZ_SA_EMAIL="service-${PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"

cat > ./iam_request.json << EOM
{
  'resource': 'projects/${PROJECT_ID}/notes/${NOTE_ID}',
    'policy': {
      'bindings': [
        {
          'role': 'roles/containeranalysis.notes.occurrences.viewer',
          'members': [
            'serviceAccount:${BINAUTHZ_SA_EMAIL}'
          ]
      }
    ]
  }
}
EOM

curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $(gcloud auth print-access-token)" --data-binary @./iam_request.json "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/${NOTE_ID}:setIamPolicy"

export KEY_LOCATION=global
export KEYRING=binauthz-keys
export KEY_NAME=lab-key
export KEY_VERSION=1

gcloud kms keyrings create $KEYRING --location=$KEY_LOCATION
gcloud kms keys create $KEY_NAME --keyring=$KEYRING --location=$KEY_LOCATION --purpose asymmetric-signing --default-algorithm=ec-sign-p256-sha256
gcloud beta container binauthz attestors public-keys add --attestor="${ATTESTOR_ID}" --keyversion-project="${PROJECT_ID}" --keyversion-location="${KEY_LOCATION}" --keyversion-keyring="${KEYRING}" --keyversion-key="${KEY_NAME}" --keyversion="${KEY_VERSION}"

cat > my_policy.yaml << EOM
defaultAdmissionRule:
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  evaluationMode: REQUIRE_ATTESTATION
  requireAttestationsBy:
    - projects/${PROJECT_ID}/attestors/vulnerability-attestor
globalPolicyEvaluationMode: ENABLE
name: projects/${PROJECT_ID}/policy
EOM

gcloud container binauthz policy import my_policy.yaml

git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git
cd cloud-builders-community/binauthz-attestation
gcloud builds submit . --config cloudbuild.yaml
cd ../..
rm -rf cloud-builders-community

gcloud builds submit . --config=cloudbuild.yaml
gcloud beta run services add-iam-policy-binding --region=us-east4 --member=allUsers --role=roles/run.invoker auth-service

```

