#!/usr/bin/env bash
set -euo pipefail

# PM Analyst Workflow Example
# This script shows the complete workflow from data analysis to shipping

echo "📊 PM Analyst Workflow Example"
echo "================================"
echo ""

# Step 1: Analysis (Manual - use therapist-data-scientist or sql-reader skill)
echo "Step 1: Analyze Data"
echo "  → Use therapist-data-scientist skill to query production data"
echo "  → Create analysis markdown file"
echo "  → Example: codel_1on1_reactions_analysis.md"
echo ""

# Step 2: Identify Opportunity (Manual - PM judgment)
echo "Step 2: Identify #1 Opportunity"
echo "  → Review analysis findings"
echo "  → Pick highest impact / lowest effort opportunity"
echo "  → Apply Impact vs. Effort matrix"
echo "  → Example: 'Reduce PR cooldown 6h→1h'"
echo ""

# Step 3: Spec the Feature (Manual - use feature-spec-writer principles)
echo "Step 3: Spec the MVP"
echo "  → Problem: What user pain are we solving?"
echo "  → Solution: What's the SMALLEST change that delivers value?"
echo "  → Metrics: How will we measure success?"
echo "  → Implementation: What needs to change?"
echo "  → Non-goals: What are we NOT doing?"
echo ""

# Step 4: Create Linear Ticket (Using linear-manager skill)
echo "Step 4: Create Linear Ticket"
echo "  → Get team ID:"
echo "    export LINEAR_API_KEY={from arsenal/.env}"
echo "    .claude/skills/linear-manager/scripts/get_teams.sh"
echo ""
echo "  → Create ticket:"
echo "    .claude/skills/linear-manager/scripts/create_issue.sh \\"
echo "      --title 'Reduce PR cooldown from 6h to 1h (ship & measure)' \\"
echo "      --team-id 'cf35cf6c-5d97-4123-a8d3-0f257364a795' \\"
echo "      --priority 'high' \\"
echo "      --description '{feature spec}'"
echo ""

# Step 5: Audit the Ticket (Manual - PM's boss lens)
echo "Step 5: AUDIT THE TICKET 🔍"
echo "  → Critical questions:"
echo "    1. Scope creep check: >1 sprint?"
echo "    2. Premature optimization check: Building for hypothetical problems?"
echo "    3. Power user bias check: Optimizing for <5% of users?"
echo "    4. Evidence-based check: Solving real or theoretical problem?"
echo "    5. Complexity cost check: What's the ROI?"
echo ""
echo "  → What to cut:"
echo "    ❌ Multi-phase plans without decision gates"
echo "    ❌ Infrastructure for unvalidated needs"
echo "    ❌ Edge cases before core value"
echo ""
echo "  → 80/20 solution:"
echo "    ✅ Ship Phase 1 alone"
echo "    ✅ Measure for 4 weeks"
echo "    ✅ THEN decide on Phase 2"
echo ""

echo "✅ Workflow Complete!"
echo ""
echo "Expected output files:"
echo "  1. {topic}_analysis.md (Step 1)"
echo "  2. CODEL-XXX Linear ticket (Step 4)"
echo "  3. {topic}_audit.md (Step 5, if cuts needed)"
echo ""
echo "Philosophy:"
echo "  'Ship 80% of value at 20% of complexity.'"
echo "  'Measure, then iterate. Avoid big design up front.'"
