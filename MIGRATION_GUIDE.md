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

**Critical Rollback Point:** `a46987f` (before migration execution)

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
git reset --hard a46987f
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

## SECTION 4: COORDINATION PROTOCOL

### Web UI and CLI Working Together

**SAFE (Can work simultaneously):**
- Reading documentation
- Viewing logs (read-only)
- Monitoring (Netdata, health checks)
- Checking git history

**DANGEROUS (Must coordinate):**
- File moves/renames → CLI only
- Git commits → One at a time
- Production deployment → CLI leads, Web verifies
- Docker changes → CLI only

### Communication via Git Commits

**Format:**
```
<type>: <subject>

<body>

Migration-Phase: <phase>
Migration-Status: <status>
Rollback-Point: a46987f
Tested: yes/no
```

### Handoff Markers

```bash
# CLI signals ready
touch /tmp/migration-cli-ready.flag

# Web signals verified
touch /tmp/migration-web-verified.flag
```

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
cp ../nexus/scripts/factsmind_logo.png scripts/
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

# Update README - Add Projects section after line 12
sed -i '12 a\\n## Projects Using Nexus\n\n### FactsMind (Migrated)\nEducational Instagram carousel generator - now in separate repository.\n\n**Repository:** [dvayreda/factsmind](https://github.com/dvayreda/factsmind)\n**Status:** Production (runs on Nexus platform)\n' README.md

# Commit
git add .
git commit -m "refactor: Extract FactsMind to separate repository

Migration-Phase: Nexus-Updated
Migration-Status: Complete
Rollback-Point: a46987f
Tested: yes"
```

### Phase 3: Deploy to Production (45 min)

```bash
# Clone FactsMind to Pi
ssh didac@100.122.207.23 << 'EOF'
cd /srv/projects
git clone https://github.com/dvayreda/factsmind.git

# Copy assets (fonts only - templates deprecated)
mkdir -p factsmind/assets/fonts
cp /srv/projects/faceless_prod/fonts/*.ttf factsmind/assets/fonts/
ls -la factsmind/
ls -la factsmind/assets/fonts/
EOF

# Update docker-compose.yml (remove templates, add fonts)
cd /home/dvayr/Projects_linux/nexus
sed -i 's|/srv/projects/faceless_prod/scripts|/srv/projects/factsmind/scripts|g' infra/docker-compose.yml
sed -i 's|/srv/projects/faceless_prod/fonts|/srv/projects/factsmind/assets/fonts|g' infra/docker-compose.yml

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

# Test paths
ssh didac@100.122.207.23 << 'EOF'
docker exec nexus-n8n ls -la /data/scripts/composite.py
docker exec nexus-n8n ls -la /data/assets/fonts/
docker exec nexus-n8n python3 -c "from PIL import Image; print('OK')"
EOF

# Manual: Test FactsMind workflow in n8n UI
# Manual: Verify carousel generation works
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
**Rollback Commit:** `a46987f` (before migration execution)
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
