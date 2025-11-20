# MIGRATION GUIDE: Nexus & FactsMind Repository Split

**Status:** Planning Document
**Created:** 2025-11-20
**Estimated Time:** 3-4 hours
**Risk Level:** LOW (with complete backups)

---

## EXECUTIVE SUMMARY

**Current State:**
- Single repository: `nexus` (mixed infrastructure + application)
- Infrastructure: Docker, n8n, helper scripts, testing
- Application: FactsMind carousel generator
- Production: Raspberry Pi at 100.122.207.23

**Target State:**
- Repository 1: `nexus` - Infrastructure platform (reusable)
- Repository 2: `factsmind` - FactsMind content project
- Zero downtime with complete rollback capability

**Critical Rollback Point:** `8afde4dc9cc0f65a138caa7b558ca900bd9d4b8b`

---

## QUICK START: DUAL CLI COORDINATION

**Recommended Setup:**

1. **Open WSL2 CLI** (Execution):
   ```bash
   cd /home/dvayr/Projects_linux/nexus
   git checkout claude/create-migration-guide-01UvbBZTVAzaaJQc3xFet7BK
   git pull
   # Then follow this guide step-by-step
   ```

2. **Keep GitHub CLI open** (Monitoring - this current session):
   - I can read files from the repository
   - I can monitor your commits for progress
   - I can answer questions about the guide
   - I **cannot** execute SSH commands or access production
   - I **cannot** run the migration for you

**Coordination Flow:**
- WSL2 CLI executes → commits with metadata → GitHub CLI monitors → repeat

See **Section 4** for detailed coordination protocol.

---

## SECTION 0: PRE-FLIGHT CHECKLIST

**RUN BEFORE STARTING MIGRATION** - Verify all prerequisites exist on production server.

```bash
# Verify fonts exist on Raspberry Pi
ssh didac@100.122.207.23 << 'EOF'
echo "=== PRE-FLIGHT CHECKLIST ==="

# Check 1: Fonts directory
if [ -d "/srv/projects/faceless_prod/fonts" ]; then
    echo "✓ Fonts directory exists"
    ls -lh /srv/projects/faceless_prod/fonts/Montserrat-*.ttf 2>/dev/null || echo "✗ ERROR: Montserrat fonts missing!"
else
    echo "✗ ERROR: Fonts directory missing at /srv/projects/faceless_prod/fonts"
    echo "  Action required: Upload Montserrat fonts before migration"
fi

# Check 2: Logo file
if [ -f "/srv/projects/faceless_prod/scripts/factsmind_logo.png" ]; then
    echo "✓ Logo file exists"
    ls -lh /srv/projects/faceless_prod/scripts/factsmind_logo.png
else
    echo "✗ ERROR: Logo missing at /srv/projects/faceless_prod/scripts/factsmind_logo.png"
    echo "  Action required: Upload logo before migration"
fi

# Check 3: composite.py script
if [ -f "/srv/projects/faceless_prod/scripts/composite.py" ]; then
    echo "✓ composite.py exists"
else
    echo "✗ ERROR: composite.py missing!"
fi

# Check 4: Disk space on /mnt/backup
BACKUP_SPACE=$(df -h /mnt/backup | awk 'NR==2 {print $4}')
echo "✓ Backup space available: $BACKUP_SPACE"

# Check 5: Docker running
if docker ps > /dev/null 2>&1; then
    echo "✓ Docker is running"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep nexus
else
    echo "✗ ERROR: Docker not accessible"
fi

# Check 6: n8n accessible
if docker exec nexus-n8n echo "OK" > /dev/null 2>&1; then
    echo "✓ n8n container accessible"
else
    echo "✗ ERROR: Cannot access nexus-n8n container"
fi

echo "=== PRE-FLIGHT COMPLETE ==="
echo ""
echo "⚠️  DO NOT PROCEED if any checks failed!"
echo "   Fix issues first, then re-run this checklist."
EOF
```

**If all checks pass ✓** → Proceed to Section 1
**If any checks fail ✗** → Fix issues first, DO NOT migrate

---

## SECTION 1: PRE-MIGRATION BACKUPS

### 1.1 Create Complete Backup (BEFORE ANY CHANGES)

```bash
# On Raspberry Pi - Create timestamped backup
ssh didac@100.122.207.23 << 'EOF'
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR=/mnt/backup/pre-migration-$BACKUP_DATE
mkdir -p $BACKUP_DIR/{db,docker-volumes,srv}

echo "Creating backup in: $BACKUP_DIR"

# 1. Stop n8n temporarily
docker stop nexus-n8n

# 2. PostgreSQL backup
docker exec -t nexus-postgres pg_dump -U faceless n8n | gzip > $BACKUP_DIR/db/postgres_n8n.sql.gz
sha256sum $BACKUP_DIR/db/postgres_n8n.sql.gz > $BACKUP_DIR/db/postgres_n8n.sql.gz.sha256

# 3. Docker volumes backup
sudo rsync -av /var/lib/docker/volumes/docker_n8n_data/_data/ $BACKUP_DIR/docker-volumes/n8n_data/

# 4. Application files backup
rsync -av /srv/ $BACKUP_DIR/srv/

# 5. Restart n8n
docker start nexus-n8n
sleep 10

echo "Backup complete: $BACKUP_DIR"
ls -lh $BACKUP_DIR
EOF
```

### 1.2 Local Git Bundle Backup

```bash
# On WSL2 - Create git bundle
cd /home/dvayr/Projects_linux/nexus
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
git bundle create /tmp/nexus-backup-$BACKUP_DATE.bundle --all
git bundle verify /tmp/nexus-backup-$BACKUP_DATE.bundle
echo "Git bundle: /tmp/nexus-backup-$BACKUP_DATE.bundle"
```

### 1.3 Verify Backups

```bash
# Verify all backups exist
ssh didac@100.122.207.23 << 'EOF'
BACKUP_DIR=$(ls -td /mnt/backup/pre-migration-* | head -1)
echo "=== BACKUP VERIFICATION ==="

# Database
[ -f "$BACKUP_DIR/db/postgres_n8n.sql.gz" ] && gunzip -t "$BACKUP_DIR/db/postgres_n8n.sql.gz" && echo "✓ Database backup OK" || echo "✗ Database FAILED!"

# Volumes
[ -d "$BACKUP_DIR/docker-volumes/n8n_data" ] && echo "✓ Docker volumes OK" || echo "✗ Volumes FAILED!"

# Files
[ -f "$BACKUP_DIR/srv/projects/faceless_prod/scripts/composite.py" ] && echo "✓ Application files OK" || echo "✗ Files FAILED!"

echo "Total backup size: $(du -sh $BACKUP_DIR | cut -f1)"
EOF
```

---

## SECTION 2: ROLLBACK PROCEDURES

### 2.1 Emergency Database Rollback

```bash
ssh didac@100.122.207.23 << 'EOF'
BACKUP_DIR=$(ls -td /mnt/backup/pre-migration-* | head -1)
docker stop nexus-n8n
docker exec -t nexus-postgres psql -U faceless -c "DROP DATABASE IF EXISTS n8n; CREATE DATABASE n8n;"
gunzip -c $BACKUP_DIR/db/postgres_n8n.sql.gz | docker exec -i nexus-postgres psql -U faceless -d n8n
docker start nexus-n8n
sleep 15
docker logs nexus-n8n --tail 50
EOF
```

### 2.2 Emergency Volume Rollback

```bash
ssh didac@100.122.207.23 << 'EOF'
BACKUP_DIR=$(ls -td /mnt/backup/pre-migration-* | head -1)
docker stop nexus-n8n
sudo rsync -av --delete $BACKUP_DIR/docker-volumes/n8n_data/ /var/lib/docker/volumes/docker_n8n_data/_data/
docker start nexus-n8n
EOF
```

### 2.3 Emergency Files Rollback

```bash
ssh didac@100.122.207.23 << 'EOF'
BACKUP_DIR=$(ls -td /mnt/backup/pre-migration-* | head -1)
rsync -av --delete $BACKUP_DIR/srv/ /srv/
EOF
```

### 2.4 Emergency Git Rollback

```bash
cd /home/dvayr/Projects_linux/nexus
git reset --hard 8afde4dc9cc0f65a138caa7b558ca900bd9d4b8b
git push --force origin main
```

### 2.5 COMPLETE SYSTEM RESTORE (Nuclear Option)

```bash
# Run emergency-rollback.sh script
./scripts/emergency-rollback.sh
```

---

## SECTION 3: ROLLBACK TRIGGERS

**ABORT MIGRATION IF:**

| Condition | Check | Action |
|-----------|-------|--------|
| n8n won't start | `docker ps \| grep nexus-n8n` | Rollback volumes + database |
| Database fails | `docker logs nexus-n8n \| grep database` | Rollback database |
| composite.py missing | `docker exec nexus-n8n ls /data/scripts/` | Rollback files |
| Import errors | `docker exec nexus-n8n python3 -c "from PIL import Image"` | Rollback volumes |
| Workflow fails | Execute test workflow | Rollback complete |

---

## SECTION 4: COORDINATION PROTOCOL - DUAL CLI SETUP

### Recommended Setup: WSL2 CLI + GitHub CLI

**Two Claude Code CLI instances working together:**

1. **WSL2 CLI (Execution Lead)** - Runs on `/home/dvayr/Projects_linux/nexus`
   - Has SSH access to Raspberry Pi
   - Executes all migration commands
   - Creates backups
   - Deploys to production
   - Runs verification tests
   - Handles emergency rollback if needed

2. **GitHub CLI (Coordinator)** - Runs from any location with GitHub access
   - Monitors migration progress via git commits
   - Creates GitHub issues for tracking
   - Can read files from repository
   - Reviews documentation
   - Cannot execute SSH/production commands
   - Provides guidance and verification

### Division of Responsibilities

**WSL2 CLI does:**
- ✅ All SSH commands to Raspberry Pi
- ✅ All git operations (commit, push, checkout)
- ✅ Docker operations via SSH
- ✅ File operations (sed, cp, mv)
- ✅ Backup creation and verification
- ✅ Emergency rollback execution

**GitHub CLI does:**
- ✅ Monitor commits for migration metadata
- ✅ Read and analyze repository files
- ✅ Provide command verification
- ✅ Track migration progress
- ✅ Answer questions about the guide
- ❌ Cannot execute SSH commands
- ❌ Cannot access production server
- ❌ Cannot run local file operations

### Communication Protocol

**WSL2 CLI commits with metadata after each phase:**
```
<type>: <subject>

<body>

Migration-Phase: <phase-name>
Migration-Status: Complete|In-Progress|Failed
Rollback-Point: 8afde4dc9cc0f65a138caa7b558ca900bd9d4b8b
Tested: yes/no
```

**GitHub CLI monitors by:**
```bash
# Check latest commit
git log -1 --format="%B"

# Parse migration metadata
git log --grep="Migration-Phase" -1
```

### Workflow Example

1. **WSL2 CLI:** Runs Section 0 pre-flight checklist
2. **WSL2 CLI:** Commits result: "chore: Pre-flight checklist passed"
3. **GitHub CLI:** Sees commit, confirms ready for Section 1
4. **WSL2 CLI:** Runs Section 1 backups
5. **WSL2 CLI:** Commits: "backup: Pre-migration backups complete"
6. **GitHub CLI:** Verifies backup metadata in commit
7. Continue pattern through all phases...

### When Things Go Wrong

**If GitHub CLI detects issues:**
- Cannot directly intervene
- Alerts user to check WSL2 CLI output
- Provides rollback commands for WSL2 CLI to execute

**If WSL2 CLI encounters errors:**
- Commits failure state
- Runs emergency rollback: `./scripts/emergency-rollback.sh`
- GitHub CLI monitors rollback commit

### Alternative: Single CLI (WSL2 Only)

You can also run the entire migration from WSL2 CLI alone:
- Follow the guide step-by-step
- Commit after each phase
- No coordination needed
- Simpler but less oversight

---

## SECTION 5: STEP-BY-STEP MIGRATION

### Phase 1: Create FactsMind Repository (30 min)

```bash
# Create new repo
cd /home/dvayr/Projects_linux
mkdir factsmind && cd factsmind
git init
git remote add origin https://github.com/dvayreda/factsmind.git

# Create structure
mkdir -p scripts assets/{fonts,logos} workflows docs examples/carousel-outputs

# Copy files
cp ../nexus/scripts/composite.py scripts/
cp ../nexus/docs/projects/factsmind.md docs/

# Create README
cat > README.md << 'EOF'
# FactsMind

Educational Instagram carousel generator powered by AI.

## Infrastructure
Runs on Nexus platform: https://github.com/dvayreda/nexus

## Documentation
See docs/factsmind.md
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
*.pyc
__pycache__/
.env
outputs/
*.png
*.jpg
!examples/*.png
EOF

# Initial commit
git add .
git commit -m "init: Create FactsMind repository

Migration-Phase: Repository-Split
Migration-Status: Initial-Commit
Tested: no"

git push -u origin main
```

### Phase 2: Update Nexus Repository (20 min)

```bash
cd /home/dvayr/Projects_linux/nexus

# Mark FactsMind files as deprecated
git mv scripts/composite.py scripts/DEPRECATED-composite.py
git mv docs/projects/factsmind.md docs/projects/DEPRECATED-factsmind.md

# Update README
cat > README.md << 'EOF'
# Nexus

Self-hosted AI content automation platform.

## Projects Using Nexus
- [FactsMind](https://github.com/dvayreda/factsmind)

## Documentation
See DOCUMENTATION_INDEX.md
EOF

# Commit
git add .
git commit -m "refactor: Extract FactsMind to separate repository

Migration-Phase: Nexus-Updated
Migration-Status: Complete
Rollback-Point: 8afde4dc9cc0f65a138caa7b558ca900bd9d4b8b
Tested: yes"
```

### Phase 3: Deploy to Production (45 min)

```bash
# Clone FactsMind to Pi
ssh didac@100.122.207.23 << 'EOF'
cd /srv/projects
git clone https://github.com/dvayreda/factsmind.git

# Copy assets (fonts and logo)
mkdir -p factsmind/assets/fonts factsmind/scripts
cp /srv/projects/faceless_prod/fonts/* factsmind/assets/fonts/ 2>/dev/null || echo "Warning: No fonts found"
cp /srv/projects/faceless_prod/scripts/*.png factsmind/scripts/ 2>/dev/null || echo "Warning: No logo found"

# Verify critical files
echo "=== PRE-DEPLOYMENT VERIFICATION ==="
ls -lh factsmind/assets/fonts/Montserrat-*.ttf || echo "ERROR: Fonts missing!"
ls -lh factsmind/scripts/factsmind_logo.png || echo "ERROR: Logo missing!"
EOF

# Update docker-compose.yml (CRITICAL: Order matters!)
cd /home/dvayr/Projects_linux/nexus

# Backup original
cp infra/docker-compose.yml infra/docker-compose.yml.backup

# 1. Update scripts path
sed -i 's|/srv/projects/faceless_prod/scripts:/data/scripts|/srv/projects/factsmind/scripts:/data/scripts|g' infra/docker-compose.yml

# 2. Remove templates line (FactsMind doesn't use templates)
sed -i '/faceless_prod\/templates:\/data\/templates/d' infra/docker-compose.yml

# 3. Add fonts mount (CRITICAL for carousel generation)
sed -i '/factsmind\/scripts:\/data\/scripts/a\      - /srv/projects/factsmind/assets/fonts:/data/fonts' infra/docker-compose.yml

# Verify changes
echo "=== DOCKER-COMPOSE.YML CHANGES ==="
diff -u infra/docker-compose.yml.backup infra/docker-compose.yml || true

# Deploy
scp infra/docker-compose.yml didac@100.122.207.23:/srv/docker/

# Restart containers
ssh didac@100.122.207.23 << 'EOF'
cd /srv/docker
docker compose down
docker compose up -d
sleep 30
docker ps
docker logs nexus-n8n --tail 50
EOF
```

### Phase 4: Verification (30 min)

```bash
# Test n8n access
curl http://100.122.207.23:5678/healthz

# Test critical paths inside container
ssh didac@100.122.207.23 << 'EOF'
echo "=== CONTAINER VERIFICATION ==="

# 1. Verify composite.py script
docker exec nexus-n8n ls -la /data/scripts/composite.py || echo "ERROR: composite.py missing!"

# 2. Verify logo file
docker exec nexus-n8n ls -la /data/scripts/factsmind_logo.png || echo "ERROR: Logo missing!"

# 3. Verify fonts directory and files
docker exec nexus-n8n ls -la /data/fonts/ || echo "ERROR: Fonts directory missing!"
docker exec nexus-n8n ls /data/fonts/Montserrat-ExtraBold.ttf || echo "ERROR: ExtraBold font missing!"
docker exec nexus-n8n ls /data/fonts/Montserrat-Regular.ttf || echo "ERROR: Regular font missing!"
docker exec nexus-n8n ls /data/fonts/Montserrat-SemiBold.ttf || echo "ERROR: SemiBold font missing!"

# 4. Verify Python dependencies
docker exec nexus-n8n python3 -c "from PIL import Image, ImageFont; print('✓ PIL OK')"

# 5. Test font loading
docker exec nexus-n8n python3 << 'PYTHON'
from PIL import ImageFont
try:
    font = ImageFont.truetype("/data/fonts/Montserrat-ExtraBold.ttf", 48)
    print("✓ Font loading OK")
except Exception as e:
    print(f"ERROR: Font loading failed: {e}")
PYTHON

echo "=== VERIFICATION COMPLETE ==="
EOF

# Manual: Test FactsMind workflow in n8n UI
# Manual: Verify carousel generation produces output images
```

### Phase 5: Cleanup (30 min)

```bash
# Create backward compatibility symlink
ssh didac@100.122.207.23 << 'EOF'
mv /srv/projects/faceless_prod /srv/projects/faceless_prod.OLD
ln -s /srv/projects/factsmind /srv/projects/faceless_prod
EOF

# Final health check
ssh didac@100.122.207.23 '~/nexus-quick.sh'
```

---

## SECTION 6: POST-MIGRATION CHECKLIST

### Immediate (Within 1 hour)
- [ ] Docker containers running
- [ ] n8n UI accessible
- [ ] Test workflow successful
- [ ] No errors in logs
- [ ] composite.py accessible
- [ ] Fonts accessible
- [ ] Git repos valid

### Short-term (24-48 hours)
- [ ] Monitor execution logs
- [ ] Verify scheduled workflows
- [ ] Check disk space
- [ ] Test carousel generation
- [ ] Verify outputs appear

### Cleanup (After 1 week)
- [ ] Remove faceless_prod.OLD
- [ ] Remove DEPRECATED files
- [ ] Archive pre-migration backups
- [ ] Merge migration branch
- [ ] Update documentation

---

## SECTION 7: ESTIMATED TIMELINE

| Phase | Duration | Downtime |
|-------|----------|----------|
| Pre-Migration Backups | 30 min | 5 min (n8n stop) |
| Repository Split | 60 min | 0 min |
| Production Deploy | 45 min | 15 min (restart) |
| Verification | 30 min | 0 min |
| Cleanup | 30 min | 0 min |
| **TOTAL** | **3-4 hours** | **20 min** |

**Best Window:** Weekday morning (09:00-12:00 CET)

---

## SECTION 8: EMERGENCY CONTACTS

**Backup Location:** `/mnt/backup/pre-migration-*` (on Pi)
**Rollback Commit:** `8afde4dc9cc0f65a138caa7b558ca900bd9d4b8b`
**Git Bundle:** `/tmp/nexus-backup-*.bundle` (on WSL2)
**Emergency Script:** `./scripts/emergency-rollback.sh`

**Health Checks:**
```bash
ssh didac@100.122.207.23 '~/nexus-quick.sh'
ssh didac@100.122.207.23 '~/nexus-health.sh'
ssh didac@100.122.207.23 '~/nexus-n8n-status.sh'
```

---

## SECTION 9: SUCCESS CRITERIA

Migration is **SUCCESSFUL** when:

✅ Both repos exist on GitHub
✅ n8n starts without errors
✅ Workflows visible in UI
✅ Test workflow executes successfully
✅ composite.py accessible in container
✅ Fonts accessible in container
✅ No errors in logs for 24 hours
✅ Scheduled workflows run correctly
✅ Carousel generation works

---

## NOTES

- Always work from backups - never delete originals until verified
- Test each phase before proceeding
- Monitor logs continuously
- Have rollback commands ready
- Don't skip verification steps
- Keep old paths as symlinks initially

**Last Updated:** 2025-11-20
**Version:** 1.0
**Status:** Ready for execution
