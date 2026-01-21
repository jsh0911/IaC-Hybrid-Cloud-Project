
    - name: Ensure manifest directory exists
      ansible.builtin.stat:
        path: "{{ petclinic_manifest_dir }}"
      register: manifest_dir

    - name: Fail if manifest dir missing
      ansible.builtin.fail:
        msg: "Manifest dir not found: {{ petclinic_manifest_dir }}"
      when: not manifest_dir.stat.exists

    - name: Create bundle.tgz from manifest dir
      ansible.builtin.command:
        cmd: "tar -czf {{ bundle_path }} -C {{ petclinic_manifest_dir }} ."
      changed_when: true

    - name: Calculate bundle sha256
      ansible.builtin.stat:
        path: "{{ bundle_path }}"
        checksum_algorithm: sha256
      register: bundle_stat

    - name: Write release.json locally
      ansible.builtin.copy:
        dest: "{{ release_json_path }}"
        mode: "0644"
        content: |
          {
            "app": "{{ app_name }}",
            "created_at_utc": "{{ ts_utc }}",
            "bundle_s3_bucket": "{{ s3_bucket_release }}",
            "bundle_s3_key": "{{ release_prefix }}/bundle.tgz",
            "bundle_sha256": "{{ bundle_stat.stat.checksum }}",
            "source_manifest_dir": "{{ petclinic_manifest_dir }}"
          }

    - name: Upload bundle.tgz to S3 release bucket
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_release }}"
        object: "{{ release_prefix }}/bundle.tgz"
        src: "{{ bundle_path }}"
        mode: put

    - name: Upload release.json to S3 release bucket
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_release }}"
        object: "{{ release_prefix }}/release.json"
        src: "{{ release_json_path }}"
        mode: put

    - name: Update LATEST_OK pointer
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_release }}"
        object: "releases/{{ app_name }}/LATEST_OK"
        content: "{{ release_prefix }}"
        mode: put

    - name: Show what was published
      ansible.builtin.debug:
        msg:
          - "Published bundle: s3://{{ s3_bucket_release }}/{{ release_prefix }}/bundle.tgz"
          - "Published release: s3://{{ s3_bucket_release }}/{{ release_prefix }}/release.json"
          - "LATEST_OK: s3://{{ s3_bucket_release }}/releases/{{ app_name }}/LATEST_OK"
YAML

ansible-playbook playbooks/11-publish-release-bundle.yml
ls -l /tmp/petclinic-20260105T054235Z.tgz || echo "NOT FOUND"
cd ~/k8s/aws-automation
cat > playbooks/11-publish-release-bundle.yml <<'YAML'
---
- name: Publish Petclinic release bundle to S3 (release bucket)
  hosts: localhost
  connection: local
  gather_facts: false

  vars_files:
    - ../group_vars/all.yml

  pre_tasks:
    - name: Generate timestamp once (stable during play)
      ansible.builtin.set_fact:
        ts_utc: "{{ lookup('pipe','date -u +%Y%m%dT%H%M%SZ') }}"

    - name: Set paths
      ansible.builtin.set_fact:
        artifacts_dir: "{{ playbook_dir }}/../artifacts"
        release_prefix: "releases/{{ app_name }}/{{ ts_utc }}"
        bundle_path: "{{ playbook_dir }}/../artifacts/{{ app_name }}-{{ ts_utc }}.tgz"
        release_json_path: "{{ playbook_dir }}/../artifacts/release-{{ app_name }}-{{ ts_utc }}.json"

    - name: Ensure artifacts dir exists
      ansible.builtin.file:
        path: "{{ artifacts_dir }}"
        state: directory
        mode: "0755"

  tasks:
    - name: Show inputs
      ansible.builtin.debug:
        msg:
          - "aws_region={{ aws_region }}"
          - "s3_bucket_release={{ s3_bucket_release }}"
          - "app_name={{ app_name }}"
          - "petclinic_manifest_dir={{ petclinic_manifest_dir }}"
          - "bundle_path={{ bundle_path }}"
          - "release_prefix={{ release_prefix }}"

    - name: Ensure manifest directory exists
      ansible.builtin.stat:
        path: "{{ petclinic_manifest_dir }}"
      register: manifest_dir

    - name: Fail if manifest dir missing
      ansible.builtin.fail:
        msg: "Manifest dir not found: {{ petclinic_manifest_dir }}"
      when: not manifest_dir.stat.exists

    - name: Create bundle.tgz (archive module)
      ansible.builtin.archive:
        path: "{{ petclinic_manifest_dir }}/"
        dest: "{{ bundle_path }}"
        format: gz

    - name: Verify bundle exists before upload
      ansible.builtin.stat:
        path: "{{ bundle_path }}"
        checksum_algorithm: sha256
      register: bundle_stat

    - name: Fail if bundle missing
      ansible.builtin.fail:
        msg: "Bundle not created: {{ bundle_path }}"
      when: not bundle_stat.stat.exists

    - name: Write release.json locally
      ansible.builtin.copy:
        dest: "{{ release_json_path }}"
        mode: "0644"
        content: |
          {
            "app": "{{ app_name }}",
            "created_at_utc": "{{ ts_utc }}",
            "bundle_s3_bucket": "{{ s3_bucket_release }}",
            "bundle_s3_key": "{{ release_prefix }}/bundle.tgz",
            "bundle_sha256": "{{ bundle_stat.stat.checksum }}",
            "source_manifest_dir": "{{ petclinic_manifest_dir }}"
          }

    - name: Upload bundle.tgz to S3 release bucket
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_release }}"
        object: "{{ release_prefix }}/bundle.tgz"
        src: "{{ bundle_path }}"
        mode: put

    - name: Upload release.json to S3 release bucket
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_release }}"
        object: "{{ release_prefix }}/release.json"
        src: "{{ release_json_path }}"
        mode: put

    - name: Update LATEST_OK pointer
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_release }}"
        object: "releases/{{ app_name }}/LATEST_OK"
        content: "{{ release_prefix }}"
        mode: put

    - name: Show what was published
      ansible.builtin.debug:
        msg:
          - "Published bundle: s3://{{ s3_bucket_release }}/{{ release_prefix }}/bundle.tgz"
          - "Published release: s3://{{ s3_bucket_release }}/{{ release_prefix }}/release.json"
          - "LATEST_OK: s3://{{ s3_bucket_release }}/releases/{{ app_name }}/LATEST_OK"
YAML

ansible-playbook playbooks/11-publish-release-bundle.yml
REGION=ap-northeast-2
BUCKET=$(grep '^s3_bucket_release:' -n group_vars/all.yml | awk '{print $2}')
REL=$(aws s3 cp "s3://${BUCKET}/releases/petclinic/LATEST_OK" - --region "$REGION")
echo "LATEST_OK => $REL"
aws s3 ls "s3://${BUCKET}/${REL}/" --region "$REGION"
aws s3 cp "s3://${BUCKET}/${REL}/release.json" - --region "$REGION"
cd ~/k8s/aws-automation
REGION=ap-northeast-2
# 1) 버킷 이름(Ansible 변수 파일에서 가져오기)
BUCKET=$(awk '/^s3_bucket_release:/{print $2}' group_vars/all.yml)
# 2) LATEST_OK 파일이 가리키는 "가장 최근 정상 릴리즈 경로" 읽기
REL=$(aws s3 cp "s3://${BUCKET}/releases/petclinic/LATEST_OK" - --region "$REGION")
echo "LATEST_OK => $REL"
# 3) 그 경로 아래 파일 목록 보기 (bundle.tgz / release.json 있어야 정상)
aws s3 ls "s3://${BUCKET}/${REL}/" --region "$REGION"
# 4) release.json 내용 확인 (버킷/키/sha256 들어있음)
aws s3 cp "s3://${BUCKET}/${REL}/release.json" - --region "$REGION"
tree
cd ~/k8s/aws-automation
mkdir -p group_vars artifacts/db
ll
cd group_vars/
ll
vim all.yml 
cd ~/k8s/aws-automation
cat > playbooks/12-mysql-backup-to-s3.yml <<'YAML'
---
- name: On-prem MySQL backup -> upload to S3 (DB bucket)
  hosts: db
  become: true
  gather_facts: false

  vars_files:
    - ../group_vars/all.yml

  vars:
    db_name: "petclinic"
    remote_backup_dir: "/var/backups/mysql"

  pre_tasks:
    - name: Generate UTC timestamp once (controller)
      delegate_to: localhost
      run_once: true
      ansible.builtin.set_fact:
        ts_utc: "{{ lookup('pipe','date -u +%Y%m%dT%H%M%SZ') }}"

    - name: Ensure backup dir exists on db-server
      ansible.builtin.file:
        path: "{{ remote_backup_dir }}"
        state: directory
        mode: "0755"

    - name: Check MySQL socket auth (sudo mysql)
      ansible.builtin.shell: "sudo mysql -NBe 'SELECT 1' >/dev/null 2>&1"
      register: socket_check
      changed_when: false
      failed_when: false

    - name: Decide dump method
      ansible.builtin.set_fact:
        use_socket_auth: "{{ socket_check.rc == 0 }}"

  tasks:
    - name: Create gzipped dump on db-server
      ansible.builtin.shell: |
        set -euo pipefail
        TS="{{ ts_utc }}"
        OUT="{{ remote_backup_dir }}/{{ db_name }}-${TS}.sql.gz"

        if {{ 'true' if use_socket_auth else 'false' }}; then
          sudo mysqldump --single-transaction --routines --triggers --events "{{ db_name }}" | gzip -c > "$OUT"
        else
          # Fallback: requires mysql_backup_user/mysql_backup_password in group_vars (or vault)
          MYSQL_PWD="{{ mysql_backup_password }}" mysqldump -h 127.0.0.1 -u "{{ mysql_backup_user }}" \
            --single-transaction --routines --triggers --events "{{ db_name }}" | gzip -c > "$OUT"
        fi

        ls -lh "$OUT"
        echo "$OUT"
      register: dump_result

    - name: Extract remote dump path
      ansible.builtin.set_fact:
        remote_dump_path: "{{ dump_result.stdout_lines[-1] }}"

    - name: Fetch dump to controller (k8s-master)
      ansible.builtin.fetch:
        src: "{{ remote_dump_path }}"
        dest: "{{ playbook_dir }}/../artifacts/db/"
        flat: true

    - name: Set local dump path
      delegate_to: localhost
      ansible.builtin.set_fact:
        local_dump_path: "{{ playbook_dir }}/../artifacts/db/{{ db_name }}-{{ ts_utc }}.sql.gz"
        s3_prefix: "{{ s3_db_prefix }}/{{ ts_utc }}"

    - name: Verify local dump exists
      delegate_to: localhost
      ansible.builtin.stat:
        path: "{{ local_dump_path }}"
        checksum_algorithm: sha256
      register: local_dump_stat

    - name: Fail if local dump missing
      delegate_to: localhost
      ansible.builtin.fail:
        msg: "Local dump not found: {{ local_dump_path }}"
      when: not local_dump_stat.stat.exists

    - name: Ensure S3 DB bucket exists (create if missing)
      delegate_to: localhost
      ansible.builtin.shell: |
        set -e
        aws s3api head-bucket --bucket "{{ s3_bucket_db }}" 2>/dev/null || \
        aws s3api create-bucket --bucket "{{ s3_bucket_db }}" --region "{{ aws_region }}" \
          --create-bucket-configuration LocationConstraint="{{ aws_region }}"
        aws s3api put-public-access-block --bucket "{{ s3_bucket_db }}" \
          --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
        aws s3api put-bucket-encryption --bucket "{{ s3_bucket_db }}" \
          --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
      changed_when: false

    - name: Upload dump to S3 (DB bucket)
      delegate_to: localhost
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_prefix }}/mysql.sql.gz"
        src: "{{ local_dump_path }}"
        mode: put

    - name: Write backup.json locally
      delegate_to: localhost
      ansible.builtin.copy:
        dest: "{{ playbook_dir }}/../artifacts/db/backup-{{ db_name }}-{{ ts_utc }}.json"
        mode: "0644"
        content: |
          {
            "db": "{{ db_name }}",
            "created_at_utc": "{{ ts_utc }}",
            "bucket": "{{ s3_bucket_db }}",
            "key": "{{ s3_prefix }}/mysql.sql.gz",
            "sha256": "{{ local_dump_stat.stat.checksum }}"
          }

    - name: Upload backup.json to S3
      delegate_to: localhost
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_prefix }}/backup.json"
        src: "{{ playbook_dir }}/../artifacts/db/backup-{{ db_name }}-{{ ts_utc }}.json"
        mode: put

    - name: Update LATEST_OK pointer (DB backups)
      delegate_to: localhost
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_db_prefix }}/LATEST_OK"
        content: "{{ s3_prefix }}"
        mode: put

    - name: Show result
      delegate_to: localhost
      ansible.builtin.debug:
        msg:
          - "Uploaded: s3://{{ s3_bucket_db }}/{{ s3_prefix }}/mysql.sql.gz"
          - "Metadata: s3://{{ s3_bucket_db }}/{{ s3_prefix }}/backup.json"
          - "LATEST_OK: s3://{{ s3_bucket_db }}/{{ s3_db_prefix }}/LATEST_OK"
YAML

ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
cd ~/k8s/aws-automation
ll
mkdir -p .secrets
vim .secrets/vault.pass
vim ansible.cfg 
cd group_vars/
ll
cd ..
cd .secrets/
ll
ls -al
vim vault.pass
cd ..
chmod 600 .secrets/vault.pass
ll
cd .secrets/
ll
ansible-playbook   --vault-password-file .secrets/vault.pass   -i ~/k8s/onprem-automation/inventory.yml   playbooks/12-mysql-backup-to-s3.yml
cd ..
ansible-playbook   --vault-password-file .secrets/vault.pass   -i ~/k8s/onprem-automation/inventory.yml   playbooks/12-mysql-backup-to-s3.yml
grep -nE '^\.secrets/?$|^\.secrets/\*$' .gitignore || echo -e "\n.secrets/\n" >> .gitignore
grep -n "mysql_backup_password" -n ~/k8s/aws-automation/playbooks/12-mysql-backup-to-s3.yml
mkdir -p ~/k8s/aws-automation/host_vars
vim ~/k8s/aws-automation/host_vars/db-server.yml
mkdir -p ~/k8s/aws-automation/group_vars/all
ansible-vault create ~/k8s/aws-automation/group_vars/all/vault.yml
ansible -i ~/k8s/onprem-automation/inventory.yml db-server   -m debug -a "var=mysql_backup_user" --ask-vault-pass
ansible -i ~/k8s/onprem-automation/inventory.yml db-server   -m debug -a "msg={{ mysql_backup_password is defined }}" --ask-vault-pass
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml --ask-vault-pass
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml --list-hosts
vim ~/k8s/aws-automation/group_vars/all.yml
ansible -i ~/k8s/onprem-automation/inventory.yml db-server   -m debug -a "msg={{ mysql_backup_password | default('NOT_SET') }}"
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
ll
vim playbooks/12-mysql-backup-to-s3.yml
cd ~/k8s/aws-automation
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
ansible -i ~/k8s/onprem-automation/inventory.yml db-server -m command -a "test -x /bin/bash && echo BASH_OK"
vim ~/k8s/aws-automation/playbooks/12-mysql-backup-to-s3.yml
cat > ~/k8s/aws-automation/playbooks/12-mysql-backup-to-s3.yml <<'YAML'
---
- name: On-prem MySQL backup -> upload to S3 (DB bucket)
  hosts: db
  gather_facts: false
  collections:
    - amazon.aws

  vars:
    db_name: "petclinic"
    backup_dir: "/var/backups/mysql"
    artifacts_dir: "{{ playbook_dir }}/../artifacts/db"

  tasks:
    - name: Generate UTC timestamp
      ansible.builtin.set_fact:
        ts_utc: "{{ lookup('pipe', 'date -u +%Y%m%dT%H%M%SZ') }}"

    - name: Default S3 db prefix if not set
      ansible.builtin.set_fact:
        s3_db_prefix: "{{ s3_db_prefix | default('db') }}"
      changed_when: false

    - name: Build S3 prefix for this backup (if not already defined)
      ansible.builtin.set_fact:
        s3_prefix: "{{ s3_db_prefix }}/{{ db_name }}/{{ ts_utc }}"
      when: s3_prefix is not defined
      changed_when: false

    - name: Build local/remote paths
      ansible.builtin.set_fact:
        remote_dump_path: "{{ backup_dir }}/{{ db_name }}-{{ ts_utc }}.sql.gz"
        local_dump_path: "{{ artifacts_dir }}/mysql-{{ db_name }}-{{ ts_utc }}.sql.gz"
        backup_json_path: "{{ artifacts_dir }}/backup-{{ db_name }}-{{ ts_utc }}.json"
      changed_when: false

    - name: Ensure artifacts dir exists locally
      delegate_to: localhost
      ansible.builtin.file:
        path: "{{ artifacts_dir }}"
        state: directory
        mode: "0755"

    - name: Ensure backup dir exists on db-server
      become: true
      ansible.builtin.file:
        path: "{{ backup_dir }}"
        state: directory
        owner: ubuntu
        group: ubuntu
        mode: "0750"

    - name: Check MySQL socket auth (sudo mysql)
      ansible.builtin.command: sudo mysql -NBe "SELECT 1;"
      register: mysql_socket_check
      changed_when: false
      failed_when: false

    - name: Decide dump method
      ansible.builtin.set_fact:
        use_socket_auth: "{{ mysql_socket_check.rc == 0 }}"
      changed_when: false

    - name: Assert MySQL creds exist when socket auth is not available
      ansible.builtin.assert:
        that:
          - mysql_backup_user is defined
          - mysql_backup_password is defined
          - (mysql_backup_user | string | length) > 0
          - (mysql_backup_password | string | length) > 0
        fail_msg: "socket auth not available; define mysql_backup_user/mysql_backup_password (preferably in vault)."
      when: not use_socket_auth
      no_log: true

    - name: Create gzipped dump on db-server (socket auth)
      ansible.builtin.shell: |
        set -euo pipefail
        OUT="{{ remote_dump_path }}"
        sudo mysqldump --single-transaction --routines --triggers --events "{{ db_name }}" \
          | gzip -c > "$OUT"
        ls -lh "$OUT"
      args:
        executable: /bin/bash
      when: use_socket_auth

    - name: Create gzipped dump on db-server (user/password)
      ansible.builtin.shell: |
        set -euo pipefail
        OUT="{{ remote_dump_path }}"
        mysqldump -h 127.0.0.1 -u "{{ mysql_backup_user }}" \
          --single-transaction --routines --triggers --events "{{ db_name }}" \
          | gzip -c > "$OUT"
        ls -lh "$OUT"
      args:
        executable: /bin/bash
      environment:
        MYSQL_PWD: "{{ mysql_backup_password }}"
      when: not use_socket_auth
      no_log: true

    - name: Fetch dump to controller
      ansible.builtin.fetch:
        src: "{{ remote_dump_path }}"
        dest: "{{ local_dump_path }}"
        flat: true

    - name: Stat local dump (sha256)
      delegate_to: localhost
      ansible.builtin.stat:
        path: "{{ local_dump_path }}"
        checksum_algorithm: sha256
      register: local_dump_stat

    - name: Upload dump to S3 (DB bucket)
      delegate_to: localhost
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_prefix }}/mysql.sql.gz"
        src: "{{ local_dump_path }}"
        mode: put

    - name: Write backup.json locally
      delegate_to: localhost
      ansible.builtin.copy:
        dest: "{{ backup_json_path }}"
        mode: "0644"
        content: |
          {
            "db": "{{ db_name }}",
            "created_at_utc": "{{ ts_utc }}",
            "bucket": "{{ s3_bucket_db }}",
            "key": "{{ s3_prefix }}/mysql.sql.gz",
            "sha256": "{{ local_dump_stat.stat.checksum }}"
          }

    - name: Upload backup.json to S3
      delegate_to: localhost
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_prefix }}/backup.json"
        src: "{{ backup_json_path }}"
        mode: put

    - name: Update LATEST_OK pointer (DB backups)
      delegate_to: localhost
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_db_prefix }}/LATEST_OK"
        content: "{{ s3_prefix }}"
        mode: put

    - name: Show result
      delegate_to: localhost
      ansible.builtin.debug:
        msg:
          - "Uploaded: s3://{{ s3_bucket_db }}/{{ s3_prefix }}/mysql.sql.gz"
          - "Metadata: s3://{{ s3_bucket_db }}/{{ s3_prefix }}/backup.json"
          - "LATEST_OK: s3://{{ s3_bucket_db }}/{{ s3_db_prefix }}/LATEST_OK"
YAML

cd ~/k8s/aws-automation
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
vim ~/k8s/aws-automation/group_vars/all.yml
cd ~/k8s/aws-automation
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
cd ~/k8s/aws-automation
# region 템플릿을 default 포함으로 치환 (모든 S3 task에 적용)
sed -i 's/region: "{{ aws_region }}"/region: "{{ aws_region | default('\''ap-northeast-2'\'') }}"/g' playbooks/12-mysql-backup-to-s3.yml
# 제대로 바뀌었는지 확인
grep -n 'region:' -n playbooks/12-mysql-backup-to-s3.yml
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
aws sts get-caller-identity
cd ~/k8s/aws-automation
# region 템플릿을 default 포함으로 치환 (모든 S3 task에 적용)
sed -i 's/region: "{{ aws_region }}"/region: "{{ aws_region | default('\''ap-northeast-2'\'') }}"/g' playbooks/12-mysql-backup-to-s3.yml
# 제대로 바뀌었는지 확인
grep -n 'region:' -n playbooks/12-mysql-backup-to-s3.yml
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
aws s3 ls
mkdir -p ~/k8s/aws-automation/group_vars/all
cat > ~/k8s/aws-automation/group_vars/all/00-s3.yml <<'YAML'
# AWS region (기본값도 걸어뒀지만 변수로도 명시)
aws_region: "ap-northeast-2"

# DB 백업 업로드 대상 버킷 (필수)
s3_bucket_db: "project06-dr-dbbackup-491085389788-apne2"

# DB 백업 최상위 prefix (선택: 없으면 플레이북 기본값 db 사용)
s3_db_prefix: "db"
YAML

cd ~/k8s/aws-automation
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
aws ec2 describe-instances --instance-ids i-0e2d2923912accf8c --profile project06-mfa --query "Reservations[0].Instances[0].[PublicIpAddress, PrivateIpAddress]"
ansible -i ~/k8s/onprem-automation/inventory.yml db-server -m debug -a "var=s3_bucket_db"
ansible -i ~/k8s/onprem-automation/inventory.yml db-server -m debug -a "var=aws_region"
ansible-inventory -i ~/k8s/onprem-automation/inventory.yml --host db-server --yaml | grep -E "aws_region|s3_bucket_db"
aws sts get-caller-identity
mkdir -p ~/k8s/aws-automation/group_vars/all
cat > ~/k8s/aws-automation/group_vars/all/00-s3.yml <<'YAML'
aws_region: "ap-northeast-2"
s3_bucket_db: "project06-dr-dbbackup-491085389788-apne2"
s3_db_prefix: "db"
YAML

cd ~/k8s/aws-automation
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
ll
cd playbooks/
ll
vim 12-mysql-backup-to-s3.yml 
cd ~/k8s/aws-automation
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
cd playbooks/
vim 12-mysql-backup-to-s3.yml 
cat > ~/k8s/aws-automation/playbooks/12-mysql-backup-to-s3.yml <<'YAML'
---
- name: On-prem MySQL backup -> create dump and fetch to controller
  hosts: db
  gather_facts: false

  vars:
    db_name: "petclinic"
    backup_dir: "/var/backups/mysql"
    artifacts_dir: "{{ playbook_dir }}/../artifacts/db"

  tasks:
    - name: Generate UTC timestamp (once)
      ansible.builtin.set_fact:
        ts_utc: "{{ lookup('pipe', 'date -u +%Y%m%dT%H%M%SZ') }}"
      run_once: true

    - name: Ensure artifacts dir exists on controller
      delegate_to: localhost
      ansible.builtin.file:
        path: "{{ artifacts_dir }}"
        state: directory
        mode: "0755"
      run_once: true

    - name: Assert required S3 vars exist on db host (for later localhost play)
      ansible.builtin.assert:
        that:
          - s3_bucket_db is defined
          - (s3_bucket_db | string | length) > 0
        fail_msg: "s3_bucket_db is undefined. Define it in group_vars/host_vars."
      run_once: true

    - name: Ensure backup dir exists on db-server
      become: true
      ansible.builtin.file:
        path: "{{ backup_dir }}"
        state: directory
        mode: "0750"

    - name: Check MySQL socket auth (sudo mysql)
      ansible.builtin.command: sudo mysql -NBe "SELECT 1;"
      register: mysql_socket_check
      changed_when: false
      failed_when: false

    - name: Decide dump method
      ansible.builtin.set_fact:
        use_socket_auth: "{{ mysql_socket_check.rc == 0 }}"
      changed_when: false

    - name: Assert MySQL creds exist when socket auth is not available
      ansible.builtin.assert:
        that:
          - mysql_backup_user is defined
          - mysql_backup_password is defined
          - (mysql_backup_user | string | length) > 0
          - (mysql_backup_password | string | length) > 0
        fail_msg: "socket auth not available; define mysql_backup_user/mysql_backup_password (preferably via vault)."
      when: not use_socket_auth
      no_log: true

    - name: Set dump paths
      ansible.builtin.set_fact:
        remote_dump_path: "{{ backup_dir }}/{{ db_name }}-{{ ts_utc }}.sql.gz"
        local_dump_path: "{{ artifacts_dir }}/mysql-{{ db_name }}-{{ ts_utc }}.sql.gz"
      changed_when: false

    - name: Create gzipped dump on db-server (socket auth)
      ansible.builtin.shell: |
        set -euo pipefail
        OUT="{{ remote_dump_path }}"
        sudo mysqldump --single-transaction --routines --triggers --events "{{ db_name }}" \
          | gzip -c > "$OUT"
        ls -lh "$OUT"
      args:
        executable: /bin/bash
      when: use_socket_auth

    - name: Create gzipped dump on db-server (user/password)
      ansible.builtin.shell: |
        set -euo pipefail
        OUT="{{ remote_dump_path }}"
        mysqldump -h 127.0.0.1 -u "{{ mysql_backup_user }}" \
          --single-transaction --routines --triggers --events "{{ db_name }}" \
          | gzip -c > "$OUT"
        ls -lh "$OUT"
      args:
        executable: /bin/bash
      environment:
        MYSQL_PWD: "{{ mysql_backup_password }}"
      when: not use_socket_auth
      no_log: true

    - name: Fetch dump to controller
      ansible.builtin.fetch:
        src: "{{ remote_dump_path }}"
        dest: "{{ local_dump_path }}"
        flat: true


- name: Upload dump/metadata to S3 from controller (no delegation)
  hosts: localhost
  gather_facts: false
  collections:
    - amazon.aws

  vars:
    db_host: "{{ groups['db'][0] }}"
    db_name: "{{ hostvars[db_host].db_name | default('petclinic') }}"
    ts_utc: "{{ hostvars[db_host].ts_utc }}"
    artifacts_dir: "{{ playbook_dir }}/../artifacts/db"
    local_dump_path: "{{ artifacts_dir }}/mysql-{{ db_name }}-{{ ts_utc }}.sql.gz"
    backup_json_path: "{{ artifacts_dir }}/backup-{{ db_name }}-{{ ts_utc }}.json"

    aws_region: "{{ hostvars[db_host].aws_region | default('ap-northeast-2') }}"
    s3_bucket_db: "{{ hostvars[db_host].s3_bucket_db }}"
    s3_db_prefix: "{{ hostvars[db_host].s3_db_prefix | default('db') }}"
    s3_prefix: "{{ (hostvars[db_host].s3_prefix | default(s3_db_prefix ~ '/' ~ db_name ~ '/' ~ ts_utc)) }}"

  tasks:
    - name: Stat local dump (sha256)
      ansible.builtin.stat:
        path: "{{ local_dump_path }}"
        checksum_algorithm: sha256
      register: local_dump_stat

    - name: Upload dump to S3 (DB bucket)
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_prefix }}/mysql.sql.gz"
        src: "{{ local_dump_path }}"
        mode: put

    - name: Write backup.json locally
      ansible.builtin.copy:
        dest: "{{ backup_json_path }}"
        mode: "0644"
        content: |
          {
            "db": "{{ db_name }}",
            "created_at_utc": "{{ ts_utc }}",
            "bucket": "{{ s3_bucket_db }}",
            "key": "{{ s3_prefix }}/mysql.sql.gz",
            "sha256": "{{ local_dump_stat.stat.checksum }}"
          }

    - name: Upload backup.json to S3
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_prefix }}/backup.json"
        src: "{{ backup_json_path }}"
        mode: put

    - name: Update LATEST_OK pointer (DB backups)
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_db_prefix }}/LATEST_OK"
        content: "{{ s3_prefix }}"
        mode: put

    - name: Show result
      ansible.builtin.debug:
        msg:
          - "Uploaded: s3://{{ s3_bucket_db }}/{{ s3_prefix }}/mysql.sql.gz"
          - "Metadata: s3://{{ s3_bucket_db }}/{{ s3_prefix }}/backup.json"
          - "LATEST_OK: s3://{{ s3_bucket_db }}/{{ s3_db_prefix }}/LATEST_OK"
YAML

cd ..
cd ~/k8s/aws-automation
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
cat > ~/k8s/aws-automation/playbooks/12-mysql-backup-to-s3.yml <<'YAML'
---
- name: On-prem MySQL backup -> create dump and fetch to controller
  hosts: db
  gather_facts: false

  vars:
    db_name: "petclinic"
    backup_dir: "/var/backups/mysql"
    artifacts_dir: "{{ playbook_dir }}/../artifacts/db"

  tasks:
    - name: Generate UTC timestamp (once)
      ansible.builtin.set_fact:
        ts_utc: "{{ lookup('pipe', 'date -u +%Y%m%dT%H%M%SZ') }}"
      run_once: true

    # 핵심: S3 관련 변수들을 "db-host facts"로 박아서 다음 localhost play에서도 항상 보이게 함
    - name: Persist S3 settings as facts on db host
      ansible.builtin.set_fact:
        aws_region: "{{ aws_region | default('ap-northeast-2') }}"
        # inventory/group_vars에서 못 읽어도 최소 동작하도록 기본값을 둠 (필요시 여기만 바꾸면 됨)
        s3_bucket_db: "{{ s3_bucket_db | default('project06-dr-dbbackup-491085389788-apne2') }}"
        s3_db_prefix: "{{ s3_db_prefix | default('db') }}"
      changed_when: false

    - name: Ensure artifacts dir exists on controller
      delegate_to: localhost
      ansible.builtin.file:
        path: "{{ artifacts_dir }}"
        state: directory
        mode: "0755"
      run_once: true

    - name: Ensure backup dir exists on db-server
      become: true
      ansible.builtin.file:
        path: "{{ backup_dir }}"
        state: directory
        mode: "0750"

    - name: Check MySQL socket auth (sudo mysql)
      ansible.builtin.command: sudo mysql -NBe "SELECT 1;"
      register: mysql_socket_check
      changed_when: false
      failed_when: false

    - name: Decide dump method
      ansible.builtin.set_fact:
        use_socket_auth: "{{ mysql_socket_check.rc == 0 }}"
      changed_when: false

    - name: Assert MySQL creds exist when socket auth is not available
      ansible.builtin.assert:
        that:
          - mysql_backup_user is defined
          - mysql_backup_password is defined
          - (mysql_backup_user | string | length) > 0
          - (mysql_backup_password | string | length) > 0
        fail_msg: "socket auth not available; define mysql_backup_user/mysql_backup_password (preferably via vault)."
      when: not use_socket_auth
      no_log: true

    - name: Set dump paths
      ansible.builtin.set_fact:
        remote_dump_path: "{{ backup_dir }}/{{ db_name }}-{{ ts_utc }}.sql.gz"
        local_dump_path: "{{ artifacts_dir }}/mysql-{{ db_name }}-{{ ts_utc }}.sql.gz"
      changed_when: false

    - name: Create gzipped dump on db-server (socket auth)
      ansible.builtin.shell: |
        set -euo pipefail
        OUT="{{ remote_dump_path }}"
        sudo mysqldump --single-transaction --routines --triggers --events "{{ db_name }}" \
          | gzip -c > "$OUT"
        ls -lh "$OUT"
      args:
        executable: /bin/bash
      when: use_socket_auth

    - name: Create gzipped dump on db-server (user/password)
      ansible.builtin.shell: |
        set -euo pipefail
        OUT="{{ remote_dump_path }}"
        mysqldump -h 127.0.0.1 -u "{{ mysql_backup_user }}" \
          --single-transaction --routines --triggers --events "{{ db_name }}" \
          | gzip -c > "$OUT"
        ls -lh "$OUT"
      args:
        executable: /bin/bash
      environment:
        MYSQL_PWD: "{{ mysql_backup_password }}"
      when: not use_socket_auth
      no_log: true

    - name: Fetch dump to controller
      ansible.builtin.fetch:
        src: "{{ remote_dump_path }}"
        dest: "{{ local_dump_path }}"
        flat: true


- name: Upload dump/metadata to S3 from controller (localhost play)
  hosts: localhost
  gather_facts: false
  collections:
    - amazon.aws

  vars:
    db_host: "{{ groups['db'][0] }}"
    db_name: "{{ hostvars[db_host].db_name | default('petclinic') }}"
    ts_utc: "{{ hostvars[db_host].ts_utc }}"
    artifacts_dir: "{{ playbook_dir }}/../artifacts/db"
    local_dump_path: "{{ artifacts_dir }}/mysql-{{ db_name }}-{{ ts_utc }}.sql.gz"
    backup_json_path: "{{ artifacts_dir }}/backup-{{ db_name }}-{{ ts_utc }}.json"

    aws_region: "{{ hostvars[db_host].aws_region }}"
    s3_bucket_db: "{{ hostvars[db_host].s3_bucket_db }}"
    s3_db_prefix: "{{ hostvars[db_host].s3_db_prefix }}"
    s3_prefix: "{{ s3_db_prefix }}/{{ db_name }}/{{ ts_utc }}"

  tasks:
    - name: Stat local dump (sha256)
      ansible.builtin.stat:
        path: "{{ local_dump_path }}"
        checksum_algorithm: sha256
      register: local_dump_stat

    - name: Upload dump to S3 (DB bucket)
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_prefix }}/mysql.sql.gz"
        src: "{{ local_dump_path }}"
        mode: put

    - name: Write backup.json locally
      ansible.builtin.copy:
        dest: "{{ backup_json_path }}"
        mode: "0644"
        content: |
          {
            "db": "{{ db_name }}",
            "created_at_utc": "{{ ts_utc }}",
            "bucket": "{{ s3_bucket_db }}",
            "key": "{{ s3_prefix }}/mysql.sql.gz",
            "sha256": "{{ local_dump_stat.stat.checksum }}"
          }

    - name: Upload backup.json to S3
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_prefix }}/backup.json"
        src: "{{ backup_json_path }}"
        mode: put

    - name: Update LATEST_OK pointer (DB backups)
      amazon.aws.s3_object:
        region: "{{ aws_region }}"
        bucket: "{{ s3_bucket_db }}"
        object: "{{ s3_db_prefix }}/LATEST_OK"
        content: "{{ s3_prefix }}"
        mode: put

    - name: Show result
      ansible.builtin.debug:
        msg:
          - "Uploaded: s3://{{ s3_bucket_db }}/{{ s3_prefix }}/mysql.sql.gz"
          - "Metadata: s3://{{ s3_bucket_db }}/{{ s3_prefix }}/backup.json"
          - "LATEST_OK: s3://{{ s3_bucket_db }}/{{ s3_db_prefix }}/LATEST_OK"
YAML

cd ~/k8s/aws-automation
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
aws configure list-profiles
ll
cd playbooks/
ll
cd ~/k8s/aws-automation
python - <<'PY'
import boto3
s=boto3.client("sts", region_name="ap-northeast-2")
print(s.get_caller_identity())
PY

aws configure list-profiles
cd playbooks/
vim 12-mysql-backup-to-s3.yml 
cd ~/k8s/aws-automation
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
cd playbooks/
vim 12-mysql-backup-to-s3.yml 
cd ~/k8s/aws-automation
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
aws configure list-profiles
cd playbooks/
vim 12-mysql-backup-to-s3.yml 
ls -la /home/ubuntu/.aws
test -f /home/ubuntu/.aws/credentials && echo CRED_OK
test -f /home/ubuntu/.aws/config && echo CONF_OK
cd ~/k8s/aws-automation
ansible-playbook -i ~/k8s/onprem-automation/inventory.yml playbooks/12-mysql-backup-to-s3.yml
aws s3 ls s3://project06-dr-dbbackup-491085389788-apne2/db/petclinic/20260105T074826Z/
aws s3 cp s3://project06-dr-dbbackup-491085389788-apne2/db/LATEST_OK -
ll
cd playbooks/
ll
cat 00-attach-ssm-role.yml 
ll
tree
cd
tree
kubectl get nodes -o wide
curl -s https://checkip.amazonaws.com
kubectl -n ingress-nginx get pods 2>/dev/null || echo "ingress-nginx not installed"
sudo apt-get update
sudo apt-get install -y ruby wget
cd /tmp
wget https://aws-codedeploy-ap-northeast-2.s3.ap-northeast-2.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo systemctl status codedeploy-agent --no-pager
aws configure
aws sts get-caller-identity
aws deploy register-on-premises-instance   --instance-name k8s-master   --iam-user-arn arn:aws:iam::491085389788:user/codedeploy-onprem   --region ap-northeast-2
aws deploy add-tags-to-on-premises-instances   --instance-names k8s-master   --tags Key=Name,Value=k8s-master   --region ap-northeast-2
sudo kubectl get nodes
cd
sudo kubectl get nodes
cd k8s/
sudo kubectl get nodes
sudo -i
echo "KUBECONFIG=$KUBECONFIG"
kubectl config view --minify
kubectl config get-contexts
cd
kubectl get nodes -o wide
ll
tree -a
cd k8s/
ll
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/baremetal/deploy.yaml
kubectl -n ingress-nginx get pods
kubectl -n ingress-nginx get svc
kubectl -n ingress-nginx get pods
kubectl -n ingress-nginx get svc
kubectl -n ingress-nginx get pods
kubectl -n ingress-nginx get svc
kubectl -n ingress-nginx describe pod ingress-nginx-controller-866cffb57-ww4g5 | sed -n '/Events/,$p'
kubectl -n ingress-nginx get pod ingress-nginx-controller-866cffb57-ww4g5 -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
clear
kubectl -n ingress-nginx get pods -o wide
kubectl -n ingress-nginx get secret ingress-nginx-admission
curl -I -H "Host: petclinic.jsh0911.com" http://192.168.20.102:31259/
kubectl apply -f k8s/petclinic.yml
kubectl get pods -l app=petclinic -o wide
cd k8s/
git clone https://github.com/jsh0911/spring-petclinic.git
ll
cd spring-petclinic/
ll
cd k8s/
ll
grep -n "host:" -n k8s/petclinic.yml || true
cd ..
grep -n "host:" -n k8s/petclinic.yml || true
sed -i 's/petclinic\.jsh0911\.com/petclinic.team3.com/g' k8s/petclinic.yml
grep -n "host:" -n k8s/petclinic.yml
kubectl apply -f k8s/petclinic.yml
kubectl get pods -l app=petclinic -o wide
kubectl get svc petclinic
kubectl get ingress petclinic
kubectl get pods -l app=petclinic -o wide
kubectl get ingress petclinic
kubectl get svc petclinic
kubectl get pods -l app=petclinic -o wide
kubectl -n ingress-nginx get pods
kubectl -n ingress-nginx get svc
kubectl describe pod petclinic-79d97458c4-kkt25 | sed -n '/Events/,$p'
kubectl describe pod petclinic-79d97458c4-qqvx7 | sed -n '/Events/,$p'
kubectl get secret demo-db
ll
kubectl delete deploy petclinic --ignore-not-found
kubectl delete svc petclinic --ignore-not-found
kubectl delete ingress petclinic --ignore-not-found
cat > /tmp/petclinic-mysql.env <<'EOF'
SPRING_DATASOURCE_URL=jdbc:mysql://192.168.20.104:3306/petclinic?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
SPRING_DATASOURCE_USERNAME=petclinic_user
SPRING_DATASOURCE_PASSWORD=Team3!@
EOF

chmod 600 /tmp/petclinic-mysql.env
kubectl create secret generic petclinic-mysql --from-env-file=/tmp/petclinic-mysql.env
rm -f /tmp/petclinic-mysql.env
kubectl get secret petclinic-mysql
cat > k8s/petclinic.yml <<'YAML'
---
apiVersion: v1
kind: Service
metadata:
  name: petclinic
spec:
  type: ClusterIP
  selector:
    app: petclinic
  ports:
    - name: http
      port: 80
      targetPort: 8080

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: petclinic
  labels:
    app: petclinic
spec:
  replicas: 2
  selector:
    matchLabels:
      app: petclinic
  template:
    metadata:
      labels:
        app: petclinic
    spec:
      containers:
        - name: petclinic
          image: dsyer/petclinic
          ports:
            - name: http
              containerPort: 8080

          # 외부 MySQL 접속정보는 Secret에서 주입
          envFrom:
            - secretRef:
                name: petclinic-mysql

          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 20
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 60
            periodSeconds: 20

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: petclinic
spec:
  ingressClassName: nginx
  rules:
    - host: petclinic.team3.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: petclinic
                port:
                  number: 80
YAML

kubectl apply -f k8s/petclinic.yml
kubectl rollout status deploy/petclinic --timeout=240s
kubectl get pods -l app=petclinic -o wide
kubectl get ingress petclinic
curl -I -H "Host: petclinic.team3.com" http://192.168.20.102:31259/
chmod +x codedeploy/scripts/*.sh
git pull
cd ~/k8s/spring-petclinic || echo "NO_REPO_DIR"
git remote -v
git log -1 --oneline
git status
git add
it stash push -m "wip: petclinic.yml update on k8s-master"
git stash push -m "wip: petclinic.yml update on k8s-master"
git status
git pull --rebase
git stash pop
git status
git add k8s/petclinic.yml
git commit -m "Update petclinic ingress host and external mysql secret env"
git push origin main
kubectl apply -f k8s/petclinic.yml
ll
nl -ba k8s/petclinic.yml | sed -n '1,60p'
cat > k8s/petclinic.yml <<'YAML'
---
apiVersion: v1
kind: Service
metadata:
  name: petclinic
spec:
  type: ClusterIP
  selector:
    app: petclinic
  ports:
    - name: http
      port: 80
      targetPort: 8080

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: petclinic
  labels:
    app: petclinic
spec:
  replicas: 2
  selector:
    matchLabels:
      app: petclinic
  template:
    metadata:
      labels:
        app: petclinic
    spec:
      containers:
        - name: petclinic
          image: dsyer/petclinic
          ports:
            - name: http
              containerPort: 8080
          envFrom:
            - secretRef:
                name: petclinic-mysql
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 20
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 60
            periodSeconds: 20

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: petclinic
spec:
  ingressClassName: nginx
  rules:
    - host: petclinic.team3.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: petclinic
                port:
                  number: 80
YAML

kubectl apply -f k8s/petclinic.yml
kubectl get pods -l app=petclinic -o wide
kubectl get ingress petclinic
curl -I -H "Host: petclinic.team3.com" http://192.168.20.102:31259/
cp k8s/petclinic.yml /tmp/petclinic.yml.good
git restore k8s/petclinic.yml
git pull --rebase
sudo systemctl status codedeploy-agent --no-pager
git restore k8s/petclinic.yml
git pull --rebase
git status
git commit -m "Fix petclinic manifest (MySQL + Ingress) and restore valid YAML"
git config --global user.email "lovegood_90@naver.com"
git config --global user.name "jsh0911"
git commit -m "Fix petclinic manifest (MySQL + Ingress) and restore valid YAML"
git push origin main
sudo systemctl status codedeploy-agent --no-pager
git status
git log -1 --oneline
sudo tail -n 200 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo ls -al /opt/codedeploy-agent/deployment-root/deployment-logs/
sudo tail -n 200 /opt/codedeploy-agent/deployment-root/deployment-logs/codedeploy-agent-deployments.log 2>/dev/null || true
sudo find / -maxdepth 3 -type f -name "*on-premises*" -o -name "*onprem*" 2>/dev/null | head
sudo systemctl restart codedeploy-agent
sudo tail -n 200 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo systemctl status codedeploy-agent --no-pager
ps -ef | grep -i [c]odedeploy
sudo ls -al /etc/codedeploy-agent 2>/dev/null || echo "NO /etc/codedeploy-agent"
sudo ls -al /opt/codedeploy-agent 2>/dev/null || echo "NO /opt/codedeploy-agent"
sudo ls -al /var/lib/codedeploy-agent 2>/dev/null || echo "NO /var/lib/codedeploy-agent"
sudo find /etc /opt /var/lib -maxdepth 4 -type f   \( -iname "*on*prem*" -o -iname "*codedeploy*conf*" -o -iname "*codedeploy*agent*" \)   -print 2>/dev/null
sudo find /etc /opt /var/lib -maxdepth 4 -type f -iname "*codedeploy*" -o -iname "*on*prem*" 2>/dev/null
sudo tee /etc/codedeploy-agent/conf/codedeploy.onpremises.yml >/dev/null <<'YAML'
---
aws_access_key_id: YOUR_ONPREM_IAM_ACCESS_KEY_ID
aws_secret_access_key: YOUR_ONPREM_IAM_SECRET_ACCESS_KEY
iam_user_arn: arn:aws:iam::123456789012:user/CodeDeployUser-OnPrem-k8s-master
region: ap-northeast-2
YAML

sudo chown root:root /etc/codedeploy-agent/conf/codedeploy.onpremises.yml
sudo chmod 600 /etc/codedeploy-agent/conf/codedeploy.onpremises.yml
ruby -ryaml -e 'p YAML.load_file("/etc/codedeploy-agent/conf/codedeploy.onpremises.yml")'
sudo systemctl restart codedeploy-agent
sudo tail -n 120 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo egrep -n "On Premises config file|169\.254\.169\.254|EHOSTUNREACH|Unauthorized|AccessDenied|InvalidClientTokenId"   /var/log/aws/codedeploy-agent/codedeploy-agent.log | tail -n 30
sudo sed -n '/2026-01-06T14:13:49/,$p' /var/log/aws/codedeploy-agent/codedeploy-agent.log | tail -n 200
sudo sed -n '/2026-01-06T14:13:49/,$p' /var/log/aws/codedeploy-agent/codedeploy-agent.log   | egrep -n "WARN|ERROR|AccessDenied|Unauthorized|InvalidClientTokenId|On Premises config file|169\.254\.169\.254"   | tail -n 80
aws --version || echo "awscli not installed"
aws sts get-caller-identity
sudo service codedeploy-agent status
tail -n 20 /var/log/aws/codedeploy-agent/codedeploy-agent.log
vim /etc/codedeploy-agent/conf/codedeploy.onpremises.yml
ll
cd /etc/
ll
cd codedeploy-agent/
ll
cd conf/
ll
cat codedeployagent.yml 
cat codedeploy.onpremises.yml 
sudo cat codedeploy.onpremises.yml 
ll
sudo vim codedeploy.onpremises.yml 
sudo service codedeploy-agent restart
tail -n 20 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo service codedeploy-agent restart
tail -n 20 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo vim /etc/codedeploy-agent/conf/codedeploy.onpremises.yml
ll
sudo vim codedeploy.onpremises.yml 
sudo service codedeploy-agent restart
tail -n 20 /var/log/aws/codedeploy-agent/codedeploy-agent.log
\
tail -n 20 /var/log/aws/codedeploy-agent/codedeploy-agent.log
ip -br a
cd
ssh k8s-node01
ssh k8s-node02
ssh db-server 
pwd
cd etc
ll
mkdir etc
cd etc/
ll
cd ..
rm -r mkdir
rm -r etc
ll
ls -al
cd
ll
pwd
find . -maxdepth 2 -mindepth 1 -type d -print | sort
clear
pwd
sudo kubeadm reset -f
sudo crictl ps -a
ip -br a | egrep 'UP|UNKNOWN'
sudo systemctl start containerd
sudo crictl stopp $(sudo crictl pods -q) 2>/dev/null || true
sudo crictl rmp   $(sudo crictl pods -q) 2>/dev/null || true
sudo crictl rm    $(sudo crictl ps -aq)  2>/dev/null || true
sudo crictl ps -a
sudo systemctl stop kubelet
sudo systemctl stop containerd
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/cni
sudo rm -rf /var/lib/calico
sudo rm -rf /var/lib/kubelet/*
sudo ip link del tunl0 2>/dev/null || true
for i in $(ip -o link show | awk -F': ' '{print $2}' | grep '^cali' 2>/dev/null); do   sudo ip link del "$i" 2>/dev/null || true; done
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X
sudo iptables -t nat -X
sudo iptables -t mangle -X
sudo systemctl daemon-reload
sudo systemctl start containerd
sudo systemctl start kubelet
ip -br a | egrep 'ens37|tunl0|cali|lo'
sudo systemctl stop kubelet
sudo systemctl stop containerd
cat <<'EOF' | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

sudo rm -f /var/run/netns/cni-* 2>/dev/null || true
sudo ls -al /var/run/netns 2>/dev/null || true
sudo rm -f /var/run/netns/* 2>/dev/null || true
sudo ip link del tunl0 2>/dev/null || true
for i in $(ip -o link show | awk -F': ' '{print $2}' | grep '^cali' || true); do   sudo ip link del "$i" 2>/dev/null || true; done
for i in cni0 flannel.1 vxlan.calico kube-ipvs0; do   sudo ip link del "$i" 2>/dev/null || true; done
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/cni
sudo rm -rf /var/lib/calico
sudo rm -rf /var/lib/flannel
sudo rm -rf /var/run/flannel
sudo rm -rf /var/lib/kubelet/*
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X
sudo iptables -t nat -X
sudo iptables -t mangle -X
ip -br a | egrep 'ens37|tunl0|cali|lo' || true
sudo reboot
cd
ifconfig
8.8.8.8
ping 8.8.8.8
ip route
exit
pwd
tree
exit
kubectl get ns | grep metallb || echo "metallb-system 없음"
kubectl edit ns metallb-system
kubectl get ns | grep metallb
# 아무것도 안 나오면 삭제 성공
kubectl edit ns metallb-system
sudo kubectl edit ns metallb-system
kubectl get ns metallb-system
kubectl -n metallb-system get pods -o wide
kubectl -n petclinic get pod -w
curl -I http://192.168.3.120/
curl -I http://192.168.3.120
kubectl -n petclinic get ingress petclinic -o wide
kubectl -n petclinic edit ingress petclinic
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
ping 8.8.8.8
ping 192.168.3.65
ping 8.8.8.8
clear
ip -br a | egrep 'ens37|tunl0|cali|lo' || true
ssh k8s-node01
ll
sudo kubeadm init   --apiserver-advertise-address=192.168.3.101   --pod-network-cidr=192.168.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
kubectl get nodes
kubectl -n kube-system get pods -o wide
kubeadm token create --print-join-command
kubectl -n kube-system get pods -o wide
kubectl get nodes
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide
ping 192.168.3.102
ssh ubuntu@192.168.3.102
ssh ubuntu@192.168.3.103
ssh ubuntu@192.168.3.104
kubectl get nodes -o wide
tree
kubectl get csr
kubeadm token create --print-join-command
ssh ubuntu@192.168.3.102
ssh ubuntu@192.168.3.103
kubectl get nodes -o wide
kubectl -n kube-system get ds calico-node -o wide
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide | egrep 'calico-node|calico-kube-controllers|coredns'
kubectl -n kube-system describe pod calico-node-lsgjd | egrep -n 'Image:|Reason:|Message:|Failed|Back-off|ErrImagePull|Pulling|Events' -A2
kubectl -n kube-system describe pod calico-node-knhpn | egrep -n 'Image:|Reason:|Message:|Failed|Back-off|ErrImagePull|Pulling|Events' -A2
ip route
kubectl -n kube-system delete pod -l k8s-app=calico-node
kubectl -n kube-system get pods -o wide | egrep 'calico-node|calico-kube-controllers'
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide | egrep 'calico-node|calico-kube-controllers'
kubectl label node k8s-node01 node-role.kubernetes.io/worker=worker --overwrite
kubectl label node k8s-node02 node-role.kubernetes.io/worker=worker --overwrite
kubectl get nodes
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl get pods -n kube-system | grep metrics-server
kubectl top nodes
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
kubectl -n ingress-nginx get pods -o wide
kubectl -n ingress-nginx get svc
kubectl -n ingress-nginx describe pod ingress-nginx-admission-create-f5nhf | egrep -n 'Image:|Reason:|Message:|Failed|Back-off|ErrImagePull|Pulling|Events' -A2
kubectl -n ingress-nginx describe pod ingress-nginx-admission-patch-z4c2m  | egrep -n 'Image:|Reason:|Message:|Failed|Back-off|ErrImagePull|Pulling|Events' -A2
ssh ubuntu@192.168.3.102
kubectl -n ingress-nginx get pods -o wide
# Admission Pod 중 하나 상세 확인
kubectl -n ingress-nginx describe pod ingress-nginx-admission-create-f5nhf
kubectl -n ingress-nginx delete pod --all
kubectl -n ingress-nginx get pods -o wide
kubectl -n ingress-nginx get svc ingress-nginx-controller
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
kubectl get ingress -A
kubectl get pods -o wide
kubectl get pods
kubectl get pods -A
ll
cd k8s/
ll
mkdir metallb
cd metallb/
vim metallb.yml
kubectl apply -f ~/k8s/metallb/metallb.yaml
kubectl apply -f ~/k8s/metallb/metallb.yml
kubectl delete namespace metallb-system --wait=true
cd
sudo vim /etc/hosts
kubectl delete namespace metallb-system --wait=true
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
kubectl get crd | egrep 'ipaddresspools|l2advertisements|bgppeers' || true
kubectl -n metallb-system get pods -o wide
kubectl get ns metallb-system -o jsonpath='{.status.phase}{"\n"}' || true
kubectl get ns metallb-system -o yaml | egrep 'phase:|finalizers:' -A2 || true
kubectl get ns metallb-system -o json > /tmp/metallb-ns.json
python3 - <<'PY'
import json
p="/tmp/metallb-ns.json"
d=json.load(open(p))
d["spec"]["finalizers"]=[]
open(p,"w").write(json.dumps(d))
print("patched")
PY

kubectl replace --raw "/api/v1/namespaces/metallb-system/finalize" -f /tmp/metallb-ns.json
kubectl get ns metallb-system || echo "metallb-system 삭제 완료"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
kubectl -n metallb-system get pods -o wide
cat <<'EOF' > ~/k8s/metallb/metallb-config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: vlan20-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.3.120-192.168.3.126
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2adv-vlan20
  namespace: metallb-system
spec:
  ipAddressPools:
    - vlan20-pool
EOF

kubectl apply -f ~/k8s/metallb/metallb-config.yaml
kubectl -n metallb-system get ipaddresspools,l2advertisements
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
kubectl -n ingress-nginx annotate svc ingress-nginx-controller metallb.universe.tf/loadBalancerIPs="192.168.3.120" --overwrite
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
kubectl get ns metallb-system
kubectl -n metallb-system get pods -o wide
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
kubectl -n metallb-system get ipaddresspools,l2advertisements
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
kubectl -n metallb-system get ipaddresspools,l2advertisements
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
kubectl -n ingress-nginx annotate svc ingress-nginx-controller   metallb.universe.tf/loadBalancerIPs="192.168.3.120" --overwrite
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
kubectl -n petclinic get deploy petclinic -o yaml | egrep 'image:'
cd k8s/
kubectl create ns petclinic
kubectl apply -n petclinic -f ~/k8s/onprem-automation/k8s/petclinic/00-mysql-external.yml
kubectl apply -n petclinic -f ~/k8s/onprem-automation/k8s/petclinic/01-petclinic.yml
kubectl -n petclinic get ingress
kubectl get ns petclinic
kubectl -n petclinic get all
kubectl -n petclinic get svc -o wide
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: petclinic
  namespace: petclinic
spec:
  ingressClassName: nginx
  rules:
    - host: www.team3pet.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: petclinic
                port:
                  number: 80
EOF

kubectl -n petclinic get ingress -o wide
kubectl -n petclinic describe ingress petclinic
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
kubectl -n petclinic get svc -o wide
kubectl -n petclinic get deploy,pod -o wide
kubectl -n petclinic describe pod petclinic-67dfcc558b-8nl2g
kubectl -n petclinic logs petclinic-67dfcc558b-8nl2g --previous=false
kubectl get pods -n petclinic
kubectl exec -it peclinic-db -n petclinic -- env | grep -i pass
grep -nE "petclinic-db|DB_PASSWORD|DB_USER|mysql .* -p|IDENTIFIED BY|create secret generic" ~/.bash_history | tail -n 50
grep -RIn --exclude-dir=.git -E "petclinic-db|DB_PASSWORD|DB_USER|DB_HOST|SPRING_DATASOURCE|mysql.*password" . | head -n 200
kubectl -n petclinic create secret generic petclinic-db   --from-literal=DB_HOST="192.168.3.104"   --from-literal=DB_PORT="3306"   --from-literal=DB_NAME="petclinic"   --from-literal=DB_USER="petclinic_user" \
kubectl -n petclinic get pod -w
kubectl -n petclinic describe pod petclinic-67dfcc558b-8nl2g | tail -n 30
kubectl -n petclinic get secret petclinic-db
kubectl -n petclinic describe pod petclinic-67dfcc558b-8nl2g | tail -n 30
kubectl -n petclinic get secret | egrep 'petclinic-db|^NAME' || echo "petclinic-db 없음"
kubectl -n petclinic describe secret petclinic-db
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
kubectl -n petclinic get secret petclinic-db
kubectl -n petclinic get pod -o wide
kubectl -n petclinic create secret generic petclinic-db   --from-literal=DB_HOST="192.168.3.104"   --from-literal=DB_PORT="3306"   --from-literal=DB_NAME="petclinic"   --from-literal=DB_USER="petclinic_user" \
kubectl -n petclinic delete secret petclinic-db --ignore-not-found
kubectl -n petclinic create secret generic petclinic-db   --from-literal=DB_HOST='192.168.3.104'   --from-literal=DB_PORT='3306'   --from-literal=DB_NAME='petclinic'   --from-literal=DB_USER='petclinic_user'   --from-literal=DB_PASSWORD='Team3!@'
kubectl -n petclinic get secret petclinic-db
kubectl -n petclinic describe secret petclinic-db
kubectl -n petclinic delete pod -l app=petclinic
kubectl -n petclinic get pod -w
kubectl -n petclinic get pod
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
kubectl -n petclinic get svc petclinic -o yaml | egrep -n 'port:|targetPort:|nodePort:|name:' -n
kubectl -n petclinic get endpoints petclinic -o wide
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=80 | egrep -i 'petclinic|upstream|connect|502|refused|timeout'
kubectl -n petclinic get pod -l app=petclinic -o wide
kubectl -n petclinic get pod -l app=petclinic -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}'
kubectl -n petclinic describe pod -l app=petclinic | egrep -n 'Ready:|Readiness|Liveness|Conditions|Events' -A3
POD=$(kubectl -n petclinic get pod -l app=petclinic -o jsonpath='{.items[0].metadata.name}')
kubectl -n petclinic exec -it "$POD" -- sh -c "ss -lntp | egrep ':8080|:80' || netstat -lntp | egrep ':8080|:80' || true"
kubectl -n petclinic logs "$POD" --tail=200
kubectl -n petclinic logs "$POD" --previous --tail=200
nc -zv 192.168.3.104 3306
kubectl -n petclinic exec -it "$POD" -- sh -c "getent hosts 192.168.3.104 || true; nc -zv 192.168.3.104 3306 || true"
ssh k8s-node02
kubectl -n petclinic describe secret petclinic-db
kubectl -n petclinic rollout restart deploy petclinic
kubectl -n petclinic get pod
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
kubectl -n petclinic get endpointslice -l kubernetes.io/service-name=petclinic -o wide
kubectl -n petclinic get pod -o wide
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
kubectl -n petclinic get svc petclinic -o wide
kubectl -n petclinic get pod -o wide --show-labels
kubectl -n petclinic get endpointslice -l kubernetes.io/service-name=petclinic -o wide
kubectl -n petclinic describe endpointslice -l kubernetes.io/service-name=petclinic | egrep -i 'Addresses|Ready|Conditions|Ports' -n
kubectl -n petclinic logs "$POD" --previous --tail=200
POD=$(kubectl -n petclinic get pod -l app=petclinic -o jsonpath='{.items[0].metadata.name}')
kubectl -n petclinic logs "$POD" --previous --tail=200
kubectl -n petclinic describe pod "$POD" | egrep -n 'Reason:|Exit Code:|OOMKilled|Last State:' -A6
kubectl -n petclinic rollout restart deploy petclinic
kubectl -n petclinic get pod
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
kubectl -n petclinic logs deploy/petclinic --tail=120
ping -c 2 192.168.3.104
ip neigh show 192.168.3.104 || arp -n | grep 192.168.3.104
nc -zv -w2 192.168.3.104 22 || true
ping 192.168.3.104
kubectl -n petclinic rollout restart deploy petclinic
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
ll
cd onprem-automation/
ll
cd k8s/
ll
cd petclinic/
ll
cat 00-mysql-external.yml 
cat 01-petclinic.yml 
kubectl -n petclinic rollout restart deploy/petclinic
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
# 마스터 노드에서 실행
kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'
kubectl -n petclinic get pods
kubectl -n petclinic get deploy,po,svc,endpointslice -o wide
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=80 | egrep -i 'www.team3pet.com|petclinic|upstream|connect|refused|timeout|502|503'
kubectl -n petclinic logs deploy/petclinic --tail=120
kubectl -n petclinic edit deploy petclinic
cd
cd k8s/
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=120 | egrep -i 'www.team3pet.com|petclinic|upstream|connect|refused|timeout|502|503'
kubectl -n petclinic edit deploy petclinic
kubectl -n petclinic get deploy,po,svc,endpointslice -o wide
kubectl -n petclinic logs deploy/petclinic --tail=80
# Ingress를 통한 접속 시도
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
kubectl -n petclinic edit endpoints mysql
kubectl -n petclinic get endpoints
# Ingress가 바라보는 서비스가 파드의 8080 포트와 잘 매핑되는지 확인
kubectl -n petclinic describe svc petclinic
# Ingress를 통한 접속 시도
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --since=2m | egrep -i 'www.team3pet.com|petclinic|upstream|connect|refused|timeout|502|503'
kubectl -n petclinic run curltest --image=curlimages/curl:8.5.0 -it --rm --restart=Never --   sh -c 'curl -sS -I -m 3 http://petclinic:80/ | head -n 10'
kubectl -n ingress-nginx run netshoot --image=nicolaka/netshoot -it --rm --restart=Never --   sh -c 'nc -zv -w2 192.168.3.102 8080; curl -sS -I -m 3 http://192.168.3.102:8080/ | head -n 10'
kubectl -n petclinic rollout restart deploy/petclinic
kubectl -n petclinic get endpoints
# Ingress가 바라보는 서비스가 파드의 8080 포트와 잘 매핑되는지 확인
kubectl -n petclinic describe svc petclinic
kubectl -n petclinic get pods --show-labels
kubectl -n petclinic get pods
kubectl -n petclinic get endpoints petclinic
kubectl -n petclinic logs petclinic-5f69d4b475-x8ktw --tail=50
kubectl -n petclinic edit deploy petclinic
kubectl -n petclinic get pods -w
kubectl -n petclinic get pods
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
kubectl -n petclinic get ingress,svc,pod -o wide
kubectl -n petclinic get endpointslice -l kubernetes.io/service-name=petclinic -o wide
kubectl -n petclinic get ingress petclinic -o wide
kubectl -n petclinic patch svc petclinic -p '{
  "spec":{
    "type":"ClusterIP",
    "ports":[{"name":"http","port":80,"targetPort":8080}]
  }
}'
kubectl -n petclinic get svc petclinic -o wide
kubectl -n petclinic get endpointslice -l kubernetes.io/service-name=petclinic -o wide
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/ | head
kubectl -n petclinic get svc,ep petclinic
curl -I -H "Host: www.team3pet.com" http://192.168.3.120/
kubectl -n petclinic get pod -l app=petclinic -o jsonpath='{range .items[*]}{.metadata.name}{" hostNetwork="}{.spec.hostNetwork}{" podIP="}{.status.podIP}{" nodeIP="}{.status.hostIP}{"\n"}{end}'
kubectl -n petclinic describe svc petclinic | egrep -n 'Selector:|TargetPort:|Endpoints:|Port:|Type:'
kubectl -n petclinic get endpointslice petclinic-t4xhv -o yaml | egrep -n 'addresses:|nodeName:|targetRef:|ready:|ports:'
kubectl -n petclinic edit deploy petclinic
kubectl -n petclinic scale deploy petclinic --replicas=2
kubectl get pods -n petclinic
kubectl -n petclinic edit ingress petclinic
ping 8.8.8.8
ping 172.3.0.1
ping 10.100.202.1
ping 116.127.207.167
ping 172.3.10.157
pwd
Private Subnet + SSM 접속
mkdir -p aws-vpc-terraform && cd aws-vpc-terraform
vim main.tf
vim variables.tf
ll
vim main.tf 
rm -f main.tf 
ll
rm -f variables.tf 
ll
vim variables.tf
vim main.tf
vim outputs.tf
ll
rm -f main.tf 
rm -f outputs.tf 
rm -f variables.tf 
ll
cd ..
ll
rm -f aws-vpc-terraform/
rm -d aws-vpc-terraform/
ll
mkdir -p terraform-jsh-vpc
cd terraform-jsh-vpc/
vim providers.tf
vim variables.tf
vim main.tf
vim outputs.tf
terraform fmt
snap install terraform
sudo snap install terraform
sudo snap install terraform --classic
terraform fmt
ll
rm -f variables.tf 
vim variables.tf
terraform fmt
terraform validate
terraform init
terraform validate
terraform plan
terraform providers
aws sts get-caller-identity
aws configure get region
terraform plan -out tfplan
terraform apply tfplan
terraform output
terraform state list
aws ssm describe-instance-information --region ap-northeast-2
vim jenkins_ec2.tf
ll
rm -f jenkins_ec2.tf 
ll
mkdir modules
cd modules/
mkdir jenkins
vim variables.tf
ll
rm -f variables.tf 
cd jenkins/
vim jenkins_ec2.tf
vim variables.tf
vim outputs.tf
ll
pwd
ll
vim user_data_jenkins.sh.tpl
ll
vim outputs.tf 
cd ..
ll
vim main.tf 
vim outputs.tf 
ll
cd modules/
cd j
cd jenkins/
ll
vim user_data_jenkins.sh.tpl 
cd ..
ll
terraform init
terraform plan
cd modules/
cd jenkins/
ll
rm -f variables.tf 
vim variables.tf
cd ~/k8s/terraform-jsh-vpc
terraform fmt -recursive
terraform init
terraform plan
cd ~/k8s/terraform-jsh-vpc
grep -nE '^\s*module\s+"' -n main.tf
grep -nE 'resource\s+"aws_vpc"|resource\s+"aws_subnet"' -n main.tf
grep -nE 'resource\s+"aws_s3_bucket"' -n main.tf
pwd
ll
cd modules/ll
cd modules/
ll
cd jenkins/
ll
cd ..
vim main.tf 
ll
vim main.tf 
ll
rm -f main.tf 
vim main.tf
clear
sudo tee /etc/systemd/system/jenkins-agent.service > /dev/null <<'EOF'
[Unit]
Description=Jenkins Inbound Agent (on-prem)
After=network-online.target
Wants=network-online.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/jenkins-agent
ExecStart=/usr/bin/java -jar /home/ubuntu/jenkins-agent/agent.jar \
  -url http://jsh-jenkins-alb-21830273.ap-northeast-2.elb.amazonaws.com/ \
  -secret 822da9bf82ef231923fda32d9b89edcb474a220feabdaace53a255e06939345b \
  -name onprem-agent \
  -workDir /home/ubuntu/jenkins-agent \
  -webSocket
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now jenkins-agent
sudo systemctl status jenkins-agent --no-pager
journalctl -u jenkins-agent -n 100 --no-pager
curl -I http://jsh-jenkins-alb-21830273.ap-northeast-2.elb.amazonaws.com/
curl -I http://jsh-jenkins-alb-21830273.ap-northeast-2.elb.amazonaws.com/ws
git@github.com:jsh0911/spring-petclinic.git
ssh git@github.com:jsh0911/spring-petclinic.git
sudo mkdir -p /root/.aws
sudo cp -a ~/.aws/credentials /root/.aws/ 2>/dev/null || true
sudo cp -a ~/.aws/config /root/.aws/ 2>/dev/null || true
sudo chmod 600 /root/.aws/credentials /root/.aws/config 2>/dev/null || true
sudo systemctl restart codedeploy-agent
sudo service codedeploy-agent status
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo /opt/codedeploy-agent/bin/codedeploy-agent start
sudo ls -al /etc/codedeploy-agent/conf/
sudo ls -al /etc/codedeploy-agent/conf/codedeploy.onpremises.yml || true
sudo grep -nE '^(host_identifier|region|iam_user_arn)\s*:' /etc/codedeploy-agent/conf/codedeploy.onpremises.yml || true
sudo sed -i 's/^region:.*/region: ap-northeast-2/' /etc/codedeploy-agent/conf/codedeploy.onpremises.yml
if sudo grep -q '^host_identifier:' /etc/codedeploy-agent/conf/codedeploy.onpremises.yml; then   sudo sed -i 's/^host_identifier:.*/host_identifier: onprem-k8s-master/' /etc/codedeploy-agent/conf/codedeploy.onpremises.yml; else   echo 'host_identifier: onprem-k8s-master' | sudo tee -a /etc/codedeploy-agent/conf/codedeploy.onpremises.yml >/dev/null; fi
sudo chmod 600 /etc/codedeploy-agent/conf/codedeploy.onpremises.yml
sudo chown root:root /etc/codedeploy-agent/conf/codedeploy.onpremises.yml
sudo systemctl restart codedeploy-agent
sleep 2
ps -ef | grep -E 'codedeploy-agent: (master|child)' | grep -v grep
sudo systemctl status codedeploy-agent --no-pager
ps -ef | grep -E 'codedeploy-agent: (master|child)' | grep -v grep
sudo journalctl -u codedeploy-agent -n 200 --no-pager
sudo tail -n 300 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo ls -al /etc/codedeploy-agent/conf/codedeploy.onpremises.yml || true
sudo grep -nE '^(host_identifier|region|iam_user_arn)\s*:' /etc/codedeploy-agent/conf/codedeploy.onpremises.yml || true
getent hosts codedeploy.ap-northeast-2.amazonaws.com
curl -sS -o /dev/null -w "%{http_code}\n" https://codedeploy.ap-northeast-2.amazonaws.com
sudo journalctl -u codedeploy-agent -n 120 --no-pager
sudoedit /etc/codedeploy-agent/conf/codedeploy.onpremises.yml
sudo systemctl restart codedeploy-agent
ps -ef | grep -E 'codedeploy-agent: (master|child)' | grep -v grep
sudo tail -n 50 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo /opt/codedeploy-agent/bin/codedeploy-agent start --verbose 2>&1 | tail -n 120
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo tail -n 200 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo journalctl -u codedeploy-agent -n 200 --no-pager
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo tail -n 120 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo tail -n 200 /var/log/aws/codedeploy-agent/codedeploy-agent.log  | grep -nE "ERROR|RuntimeError|AccessDenied|InvalidClientToken|SignatureDoesNotMatch|ExpiredToken|Unable to locate credentials" || true
ps -ef | grep codedeploy-agent
sudo tail -n 5 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo grep -nE '^2026-01-15T10:' /var/log/aws/codedeploy-agent/codedeploy-agent.log | tail -n 200
sudo journalctl -u codedeploy-agent --since "2026-01-15 10:19:00" --no-pager -n 200
aws deploy get-deployment   --region ap-northeast-2   --deployment-id d-RBQXKDJDG   --query 'deploymentInfo.status'   --output text
aws deploy get-deployment-instance   --region ap-northeast-2   --deployment-id d-RBQXKDJDG   --instance-id onprem-k8s-master   --query 'instanceSummary.lifecycleEvents[*].{name:lifecycleEventName,status:status,diag:diagnostics.message}'   --output table
sudo tail -n 200 /var/log/aws/codedeploy-agent/codedeploy-agent.log
aws deploy get-deployment   --region ap-northeast-2   --deployment-id <NEW_DEPLOYMENT_ID>   --query 'deploymentInfo.status'   --output text
aws deploy get-deployment   --region ap-northeast-2   --deployment-id d-D9K7LSJDG   --query 'deploymentInfo.status'   --output text
aws deploy get-on-premises-instance --region ap-northeast-2 --instance-name onprem-k8s-master
aws deploy get-deployment   --region ap-northeast-2   --deployment-id d-D9K7LSJDG   --query 'deploymentInfo.status'   --output text
sudo tail -n 400 /var/log/aws/codedeploy-agent/codedeploy-agent.log | grep -nE "ERROR|FATAL|AccessDenied|SignatureDoesNotMatch|InvalidClientToken|Unable to locate|No such file|permission denied"
sudo grep -n "d-D9K7LSJDG"   /opt/codedeploy-agent/deployment-root/deployment-logs/codedeploy-agent-deployments.log   | tail -n 200
DGID="$(sudo grep -oE '/deployment-root/[0-9a-f-]+/d-D9K7LSJDG' -m1 \
  /var/log/aws/codedeploy-agent/codedeploy-agent.log \
  | awk -F/ '{print $(NF-1)}')"
echo "DGID=$DGID"
sudo ls -al "/opt/codedeploy-agent/deployment-root/$DGID/d-D9K7LSJDG/logs" || true
sudo tail -n 200 "/opt/codedeploy-agent/deployment-root/$DGID/d-D9K7LSJDG/logs/scripts.log" || true
aws s3 cp   "s3://project06-dr-dbbackup-491085389788-apne2/releases/petclinic/20260115T013109Z/bundle.zip"   /tmp/bundle.zip
unzip -l /tmp/bundle.zip | sed -n '1,80p'
sudo find /opt/codedeploy-agent/deployment-root -maxdepth 5   -type d -name "d-D9K7LSJDG" -o -type f -name "*d-D9K7LSJDG*" 2>/dev/null
sudo find /opt/codedeploy-agent/deployment-root -maxdepth 3 -type d | sed -n '1,120p'
sudo ls -al "/opt/codedeploy-agent/deployment-root/95bd7022-e7db-4ca7-92eb-2ee3a684349b" || true
cd /opt/codedeploy-agent/deployment-root/95bd7022-e7db-4ca7-92eb-2ee3a684349b
ll
cd d-D9K7LSJDG/
ll
# 특정 배포 ID의 상세 에러 로그 확인
sudo tail -n 50 /var/log/aws/codedeploy-agent/codedeploy-agent.log
sudo grep -nE "d-D9K7LSJDG|Command Name = BeforeInstall|BeforeInstall"   /var/log/aws/codedeploy-agent/codedeploy-agent.log | tail -n 200
sudo grep -nE "d-D9K7LSJDG|put_host_command_(acknowledgement|complete)|ERROR"   /var/log/aws/codedeploy-agent/codedeploy-agent.log | tail -n 300
ls -al /opt/codedeploy/petclinic
sudo mkdir -p /opt/codedeploy/petclinic
sudo chown -R ubuntu:ubuntu /opt/codedeploy/petclinic
cd codedeploy/scripts/cleanup.sh
cd /opt/codedeploy
ll
cd petclinic/
ll
cd
unzip -l /tmp/bundle.zip | grep -E 'codedeploy/scripts/(cleanup|deploy_k8s|validate)\.sh'
sudo find /opt/codedeploy-agent/deployment-root -name "scripts.log" -o -name "*.log" | tail -n 50
cd /opt/codedeploy/petclinic
ll
ls -al
cd ..
ll
mkdir scripts
sudo mkdir scripts
cd scripts/
vim cleanup.sh
sudo vim cleanup.sh
unzip -l bundle.zip | grep -E 'codedeploy/scripts/cleanup.sh'
sudo find /opt/codedeploy-agent/deployment-root -type f \( -name "scripts.log" -o -name "*deployments*.log" \) -print | tail -n 50
ll
cd ..
ll
cd petclinic/
ll
cd ..
ls -al
cd
kubectl describe pod -l app=petclinic | tail -n 120 || true
kubectl -n default create secret docker-registry dockerhub-regcred   --docker-server=https://index.docker.io/v1/   --docker-username='josohyun'   --docker-password='dckr_pat_CmnJXoWVWEVxCsJI7BAbuMcOzMQ'   --docker-email='j_sohyun@kakao.com'
kubectl -n default patch serviceaccount default   -p '{"imagePullSecrets":[{"name":"dockerhub-regcred"}]}'
kubectl rollout restart deploy/petclinic
kubectl get pods -l app=petclinic -o wide
kubectl -n default get secret dockerhub-cred
kubectl -n default get sa default -o yaml | sed -n '1,120p'
kubectl -n default delete pod -l app=petclinic
kubectl -n default get pod -l app=petclinic
kubectl describe pod -l app=petclinic | tail -n 120 || true
ubuntu@k8s-master:~$ kubectl get pod -n default -l app=petclinic
NAME                         READY   STATUS             RESTARTS       AGE
petclinic-5ffb4dcbd-jlzr2    0/1     CrashLoopBackOff   4 (23s ago)    11m
petclinic-68fd8956d-tdnhp    0/1     Running            1 (35s ago)    2m32s
petclinic-757b7f5789-r9znp   0/1     Error              4 (105s ago)   8m35s
kubectl describe pod -n default petclinic-5ffb4dcbd-jlzr2 | sed -n '1,220p'
kubectl logs -n default petclinic-5ffb4dcbd-jlzr2 --previous --tail=200
kubectl logs -n default petclinic-757b7f5789-r9znp --previous --tail=200
kubectl -n default logs -l app=petclinic --all-containers=true --tail=200 --previous
kubectl logs -l app=petclinic --tail=120
