cd 'C:\Users\kance\Documents\GitHub\Questie-X'
git add -A
git commit -m "feat: v1.4.0 - Code review fixes and taint resolution

- C_Timer OnUpdate uses elapsed param
- IsAchievementCompletion checks completion boolean
- C_Map.GetPlayerMapPosition fixes
- QuestieLearner GUID function forward declarations
- Taint guards on secure hooks (InCombatLockdown + pcall)

Fixes ADDON_ACTION_BLOCKED: UseAction() errors"
git push