# Expendria: Your Personal Expense Tracker 💰

⬇️ **Download the latest APK here:** [expendria.apk](expendria.apk)

Expendria is a powerful and intuitive mobile application built with Flutter, designed to help you effortlessly track and manage your daily, weekly, monthly, and yearly expenses. It provides a comprehensive suite of features to give you clear insights into your spending habits directly on your mobile device.

---

## ✨ Features

- **Expense Tracking**: Record individual expense items with their name, cost, and date.
- **Interactive Calendar View**: Visually inspect your total expenses for each day directly on an integrated calendar.
- **Dynamic Charts**: Visualize your spending patterns with interactive weekly, monthly, and yearly charts, powered by [fl_chart](https://pub.dev/packages/fl_chart).
- **In-App Calculator**: Seamlessly perform calculations for expense amounts using an integrated calculator.
- **Local Data Persistence**: All your financial data is securely stored locally on your device using [SQFlite](https://pub.dev/packages/sqflite), ensuring privacy and offline access.
- **PDF Export**: Generate professional PDF reports of your expenses for easy sharing or record-keeping.
- **Responsive Design**: Built with Flutter, the app offers a consistent and responsive user experience across various Android devices.

---

## 🚀 Getting Started

Follow these steps to get Expendria up and running on your local development machine.

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.0.0 or higher recommended)
- Android Studio or VS Code with Flutter and Dart plugins installed
- An Android emulator or physical device

---

## ✍️ How to Use

### Dashboard

- The main screen presents your overall expense summary, charts, and calendar.

### Adding Expenses

- Tap on a date in the calendar to add or view expenses for that specific day.
- Enter the item name and amount.
- Use the in-app calculator if needed for quick sums.
- Save your entries to update the daily total and refresh charts.

### Viewing Reports

- Navigate through weekly, monthly, and yearly views on the charts to gain different perspectives on your spending.

### PDF Export

- Tap the export option (button or menu item) to generate a PDF of your expense data for sharing or storing.

---

## 📂 Project Structure

```

expendria/
├── lib/                     # Application source code
│   └── main.dart            # Main entry point and core logic
├── build/                   # Compiled application outputs (e.g., .apk)
├── pubspec.yaml             # Project dependencies and metadata
├── README.md                # This README file
└── ...other Flutter files

```

---

## ⚠️ Important Considerations

- **Local Storage**: Expense data is stored directly on the device where the app is installed. Clearing app data or uninstalling the app will result in data loss.
- **No Cloud Sync**: This version does not include cloud synchronization. Data is tied to the individual device.
- **Security**: While data is stored locally, it is important to ensure your device is secured. The app does not implement complex encryption for local data beyond what SQFlite provides.

---

## 🤝 Contributing

Contributions are welcome! If you have suggestions for improvements or new features, feel free to fork the repository and submit pull requests.

---

## 📄 License

This project is open-source and available under the [MIT License](https://opensource.org/licenses/MIT).

---

## Acknowledgements

- [Flutter](https://flutter.dev/) for the amazing framework  
- [fl_chart](https://pub.dev/packages/fl_chart) for interactive charts  
- [table_calendar](https://pub.dev/packages/table_calendar) for the customizable calendar  
- [sqflite](https://pub.dev/packages/sqflite) for local database management  
- [pdf](https://pub.dev/packages/pdf) for PDF generation  
- [open_filex](https://pub.dev/packages/open_filex) for opening files  
- [math_expressions](https://pub.dev/packages/math_expressions) for mathematical expression parsing
```
