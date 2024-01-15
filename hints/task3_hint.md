# Hint: regression_tests

A recent commit changed a default value in `router.py`. Use git to find which one.

```bash
# Step 1: See the full commit history
git log --oneline

# Step 2: Start a bisect
git bisect start
git bisect bad                  # current HEAD is broken
git bisect good <early-sha>     # pick a commit from git log where things were good
                                # git will check out commits between them

# Step 3: At each step, check if router.py is broken
grep "max_retries" router.py    # tell git bisect good or bad based on what you see
git bisect good                 # or: git bisect bad

# Step 4: git bisect will identify the first bad commit
git bisect reset                # done — return to HEAD

# Step 5: Revert the bad commit
git revert <bad-commit-sha>     # creates a new commit that undoes the change
```

**Important:** Use `git revert`, not `git reset --hard`.
Reverting creates a new commit (traceable, reversible).
Resetting rewrites history (breaks teammates, obscures what happened).
