# Release Readiness Checklist

## Backend
- [ ] Set `FLASK_ENV=production`
- [ ] Set strong `SECRET_KEY` and `JWT_SECRET`
- [ ] Set `CORS_ORIGINS` to the allowed app origins only
- [ ] Confirm `/api/health` returns 200
- [ ] Confirm request IDs appear in logs and response headers
- [ ] Run backend tests from `fin_backend/tests`

## Mobile
- [ ] Set `BACKEND_URL` in `fin_mobile/.env`
- [ ] Confirm `BACKEND_URL` resolves through `resolveBackendUrl()`
- [ ] Run Flutter analysis
- [ ] Run the Flutter API contract test

## Android Release
- [ ] Verify cleartext traffic is disabled for release builds
- [ ] Verify release signing is configured
- [ ] Build release APK/AAB

## Operational Checks
- [ ] Confirm auth rate limiting is active
- [ ] Confirm OTP response does not expose the code
- [ ] Confirm smoke tests cover auth + transaction creation
- [ ] Confirm dashboard loads without parse errors

## Go/No-Go
- [ ] No critical errors in backend tests
- [ ] No hard Flutter analyzer errors
- [ ] No release-only network security exceptions
- [ ] No secrets committed in repo
