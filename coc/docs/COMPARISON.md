# Comparison: my first Flutter build vs your React project (Conect1)

| Area | First Flutter build (mine) | Your React + Spring Boot project | New Flutter + Firebase build |
|---|---|---|---|
| Scope | 8 static screens copied from the Figma screenshot | ~35 routes, full backend (V1–V4 SQL migrations) | Every feature of the React app + the Figma look |
| Auth | none | register / login / JWT + refresh, email verified flag, roles | Firebase Auth: sign up, log in, reset password, verification email, roles |
| Data | hard-coded lists | PostgreSQL, 20+ tables | Cloud Firestore (real time), security rules |
| Feed | one demo post | For you / Latest, compose, like, save, comment page, delete with **undo**, report | all of it, plus topic tags & image link |
| Social graph | — | follow / followers / following, people search, privacy (visibility, searchable, message requests) | all of it (connection = mutual follow, same rule as backend) |
| Groups | list + join toggle (local) | list, create, detail, join/leave, manage/delete | all of it |
| Messaging | local bubbles | conversations, messages, read receipts, notifications, voice-call signalling stub | real-time chat, read receipts, privacy checks, voice call via Jitsi |
| Study | static dark card | rooms, schedule, join, shared notes | Figma live card, game plan, schedule, join/leave, Jitsi video, shared notes (add/edit/delete) |
| Events | — | official events, publish only for verified orgs | same, incl. admin verification |
| AI assistant | canned reply | external research links | searches your Firestore data + external research links |
| Notifications | local list | list + mark read | live list, unread badge, mark all read, deep links |
| Settings | list only | theme, text size, contrast, education focus, privacy | all of it + change password |
| Admin | — | user management, report review | same |
| Look & feel | Figma mobile layout | desktop sidebar layout | Figma mobile layout (bottom bar + menu), light/dark |

## Things the React app did that I kept on purpose
Soft delete with undo window · education-only feed filter · message-request rules (`CAMPUS / CONNECTIONS / NOBODY`) ·
profile visibility rules · verified-organization event publishing · admin moderation (keep / remove post).

## Things the Figma design had that the React app did not (added here)
Bio and interests on profiles · "game plan" agenda on study sessions · live-session hero card · assistant chat layout ·
unread filter on notifications · bottom navigation.

## Things that changed because Firebase replaces the Spring Boot server
JWT → Firebase Auth tokens · SQL joins → denormalised fields (author name on posts, `memberIds` arrays) ·
REST validation → Firestore rules · 5-second polling → live snapshots · password hashing / refresh tokens → handled by Firebase.
