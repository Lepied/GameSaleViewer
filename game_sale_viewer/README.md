# GameDeal Hunter 🎮

멀티 플랫폼 게임 할인 정보 통합 서비스

## 프로젝트 개요

GameDeal Hunter는 스팀(Steam), 에픽게임즈 스토어, GOG 등 파편화된 PC 게임 유통 플랫폼의 가격 정보를 하나의 앱으로 통합하여 제공하는 게임 가격 비교 및 큐레이션 서비스입니다.

## 주요 기능

### 1. 통합 가격 검색
- 게임 타이틀 입력 시 전 세계 주요 스토어의 가격 비교
- 최저가 순으로 정렬
- 스토어별 필터링 기능

### 2. Deal Rating 시스템
- 정가 대비 할인율과 메타크리틱 점수를 종합하여 딜 평가
- Super Deal, Good Deal, Fair Deal, Wait 등급으로 시각화
- 오늘의 미친 특가: 75% 이상 할인 + 메타크리틱 80점 이상 게임 자동 큐레이션

### 3. 찜 목록 관리
- Supabase 연동으로 개인별 찜 목록 관리
- 찜한 게임의 가격 변동 추적
- 로그인/회원가입 기능

### 4. 게임 상세 정보
- 여러 스토어의 가격 비교
- 스토어로 이동하여 구매 기능
- Steam 페이지 바로가기

## 기술 스택

- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL)
- **API**: CheapShark API
- **상태 관리**: Provider
- **이미지 캐싱**: cached_network_image
- **URL 런처**: url_launcher

## 설치 및 실행

### 1. Flutter 설치
```bash
# Flutter SDK 설치 확인
flutter doctor
```

### 2. 프로젝트 클론
```bash
git clone https://github.com/YOUR_USERNAME/GameSaleViewer.git
cd GameSaleViewer/game_sale_viewer
```

### 3. 패키지 설치
```bash
flutter pub get
```

### 4. 웹에서 실행
```bash
flutter run -d chrome
```

### 5. 다른 플랫폼에서 실행
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

## 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── models/                   # 데이터 모델
│   ├── game_deal.dart
│   ├── game_detail.dart
│   ├── store.dart
│   └── favorite.dart
├── services/                 # API 서비스
│   ├── cheapshark_api_service.dart
│   └── supabase_service.dart
├── providers/                # 상태 관리
│   ├── game_provider.dart
│   └── auth_provider.dart
├── screens/                  # 화면
│   ├── home_screen.dart
│   ├── search_screen.dart
│   ├── game_detail_screen.dart
│   ├── favorites_screen.dart
│   └── auth_screen.dart
├── widgets/                  # 재사용 위젯
│   ├── game_deal_card.dart
│   └── store_filter.dart
└── utils/                    # 유틸리티
    └── supabase_config.dart
```

## 사용 방법

### 1. 홈 화면
- 오늘의 특가: 할인율 75% 이상 + 메타크리틱 80점 이상 게임
- 스토어 필터: Steam, Epic, GOG 등으로 필터링
- 게임 딜 카드: 게임 정보, 가격, 할인율, Deal Rating 표시

### 2. 검색
- 상단 검색 아이콘 클릭
- 게임 이름 입력하여 검색
- 검색 결과에서 게임 선택하여 상세 정보 확인

### 3. 찜하기
- 게임 카드의 하트 아이콘 클릭
- 로그인 필요 (로그인하지 않은 경우 로그인 화면으로 이동)
- 찜 목록에서 찜한 게임 관리

### 4. 게임 상세 정보
- 게임 카드 클릭하여 상세 화면 진입
- 여러 스토어의 가격 비교
- "구매" 버튼으로 해당 스토어로 이동
- "Steam에서 보기" 버튼으로 Steam 페이지 열기

### 5. 로그인/회원가입
- 상단 우측 로그인 아이콘 클릭
- 이메일과 비밀번호로 회원가입/로그인
- 로그인 후 찜 목록 기능 사용 가능

## API 정보

### CheapShark API
- Base URL: https://www.cheapshark.com/api/1.0
- 무료 API (API Key 불필요)
- 30개 이상의 글로벌 게임 스토어 데이터 제공

### 주요 엔드포인트
- `GET /deals`: 게임 딜 목록 조회
- `GET /games?title={keyword}`: 게임 검색
- `GET /games?id={id}`: 게임 상세 정보
- `GET /stores`: 스토어 목록 조회

## 주의사항

⚠️ **Supabase 설정 필수**
- 앱을 실행하기 전에 Supabase 프로젝트를 생성하고 설정해야 합니다
- `lib/utils/supabase_config.dart` 파일에 실제 URL과 Key를 입력해야 합니다
- Supabase를 설정하지 않으면 로그인/찜하기 기능을 사용할 수 없습니다

⚠️ **웹 실행 시**
- CORS 이슈가 발생할 수 있습니다
- Chrome에서 실행 시: `flutter run -d chrome --web-browser-flag "--disable-web-security"`

## 개발 정보

- **개발 언어**: Dart
- **프레임워크**: Flutter
- **최소 SDK**: Dart 3.7.2 이상
- **지원 플랫폼**: Web, Android, iOS, Windows, macOS, Linux

## 라이선스

이 프로젝트는 교육 목적으로 작성되었습니다.

## 기여

버그 리포트나 기능 제안은 이슈로 등록해주세요.

---

Made with ❤️ using Flutter
