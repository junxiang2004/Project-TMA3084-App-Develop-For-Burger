import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'financial record.dart';

class Event {
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String location;

  Event({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'location': location,
  };

  factory Event.fromJson(Map<String, dynamic> json) => Event(
    name: json['name'],
    startDate: DateTime.parse(json['startDate']),
    endDate: DateTime.parse(json['endDate']),
    location: json['location'] ?? '',
  );
}

class LedgerEntry {
  final String id;
  final String eventName;
  final String description;
  final double amount;
  final bool isIncome;
  final String category;
  final DateTime? transactionDate;

  LedgerEntry({
    required this.id,
    required this.eventName,
    required this.description,
    required this.amount,
    required this.isIncome,
    required this.category,
    this.transactionDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventName': eventName,
    'description': description,
    'amount': amount,
    'isIncome': isIncome,
    'category': category,
    'transactionDate': transactionDate?.toIso8601String(),
  };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    id: json['id'],
    eventName: json['eventName'],
    description: json['description'],
    amount: (json['amount'] as num).toDouble(),
    isIncome: json['isIncome'],
    category: json['category'],
    transactionDate: json['transactionDate'] != null
        ? DateTime.tryParse(json['transactionDate'])
        : null,
  );
}

class StorageService {
  Future<void> saveEvents(List<Event> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'fr_events',
      json.encode(events.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveLedger(List<LedgerEntry> ledger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'fr_ledger',
      json.encode(ledger.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<Event>> fetchEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('fr_events');
    if (data != null) {
      return (json.decode(data) as List).map((e) => Event.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<LedgerEntry>> fetchLedger() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('fr_ledger');
    if (data != null) {
      return (json.decode(data) as List)
          .map((e) => LedgerEntry.fromJson(e))
          .toList();
    }
    return [];
  }
}

class LocalDataStore extends ChangeNotifier {
  static final LocalDataStore instance = LocalDataStore._internal();
  LocalDataStore._internal();

  final StorageService _storage = StorageService();
  List<Event> events = [];
  List<LedgerEntry> ledger = [];
  bool isLoaded = false;

  Future<void> loadData() async {
    if (isLoaded) return;
    events = await _storage.fetchEvents();
    ledger = await _storage.fetchLedger();
    isLoaded = true;
    notifyListeners();
  }

  void addEvent(Event event) {
    events.add(event);
    _storage.saveEvents(events);
    notifyListeners();
  }

  void updateEvent(Event oldEvent, Event updatedEvent) {
    final index = events.indexWhere((e) => e.name == oldEvent.name);
    if (index != -1) {
      events[index] = updatedEvent;
      // If event name changed, sync linked ledger records
      if (oldEvent.name != updatedEvent.name) {
        for (int i = 0; i < ledger.length; i++) {
          if (ledger[i].eventName == oldEvent.name) {
            ledger[i] = LedgerEntry(
              id: ledger[i].id,
              eventName: updatedEvent.name,
              description: ledger[i].description,
              amount: ledger[i].amount,
              isIncome: ledger[i].isIncome,
              category: ledger[i].category,
              transactionDate: ledger[i].transactionDate,
            );
          }
        }
        _storage.saveLedger(ledger);
      }
      _storage.saveEvents(events);
      notifyListeners();
    }
  }

  void deleteEvent(Event event) {
    events.removeWhere((e) => e.name == event.name);
    ledger.removeWhere((e) => e.eventName == event.name);
    _storage.saveEvents(events);
    _storage.saveLedger(ledger);
    notifyListeners();
  }

  void addLedgerEntry(LedgerEntry entry) {
    ledger.add(entry);
    _storage.saveLedger(ledger);
    notifyListeners();
  }

  void updateLedgerEntry(LedgerEntry updatedEntry) {
    final index = ledger.indexWhere((e) => e.id == updatedEntry.id);
    if (index != -1) {
      ledger[index] = updatedEntry;
      _storage.saveLedger(ledger);
      notifyListeners();
    }
  }

  void deleteLedgerEntry(String id) {
    ledger.removeWhere((e) => e.id == id);
    _storage.saveLedger(ledger);
    notifyListeners();
  }
}

class EventManagementPage extends StatefulWidget {
  const EventManagementPage({super.key});

  @override
  State<EventManagementPage> createState() => _EventManagementPageState();
}

class _EventManagementPageState extends State<EventManagementPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    LocalDataStore.instance.loadData().then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  String _formatDate(DateTime date) {
    return date.toString().split(' ')[0];
  }

  void _showEventDialog({Event? existingEvent}) {
    final isEditing = existingEvent != null;
    final nameController = TextEditingController(
      text: existingEvent?.name ?? '',
    );
    final locationController = TextEditingController(
      text: existingEvent?.location ?? '',
    );
    DateTime? startDate = existingEvent?.startDate;
    DateTime? endDate = existingEvent?.endDate;

    final startDateController = TextEditingController(
      text: startDate != null ? _formatDate(startDate) : '',
    );
    final endDateController = TextEditingController(
      text: endDate != null ? _formatDate(endDate) : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isEditing ? Icons.edit_calendar : Icons.add_box_rounded,
              color: Colors.blueGrey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              isEditing ? 'Edit Event' : 'Create New Event',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Event Name',
                  hintText: 'Enter event name',
                  prefixIcon: const Icon(Icons.event_note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  hintText: 'Enter location',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: startDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Start Date',
                  hintText: 'Select Start Date',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: startDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    startDateController.text = _formatDate(pickedDate);
                    startDate = pickedDate;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'End Date',
                  hintText: 'Select End Date',
                  prefixIcon: const Icon(Icons.event_available),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: endDate ?? startDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    endDateController.text = _formatDate(pickedDate);
                    endDate = pickedDate;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final inputName = nameController.text.trim();
              final inputLocation = locationController.text.trim();

              if (inputName.isEmpty || startDate == null || endDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please enter an event name and select both start and end dates.',
                    ),
                  ),
                );
                return;
              }

              final newEvent = Event(
                name: inputName,
                startDate: startDate!,
                endDate: endDate!,
                location: inputLocation.isNotEmpty ? inputLocation : inputName,
              );

              if (isEditing) {
                LocalDataStore.instance.updateEvent(existingEvent, newEvent);
              } else {
                LocalDataStore.instance.addEvent(newEvent);
              }
              Navigator.pop(context);
            },
            child: Text(isEditing ? 'Save Changes' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEvent(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete "\${event.name}" and all of its financial records?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              LocalDataStore.instance.deleteEvent(event);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Event Financial Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: LocalDataStore.instance,
              builder: (context, _) {
                final events = LocalDataStore.instance.events;

                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 64,
                          color: Colors.blueGrey.shade200,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No events found. Please create one.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blueGrey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      elevation: 2,
                      shadowColor: Colors.black12,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FinancialDashboardPage(event: event),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.event,
                                  color: Colors.blueGrey.shade700,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.date_range,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${_formatDate(event.startDate)} →${_formatDate(event.endDate)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (event.location.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.place_outlined,
                                            size: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              event.location,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit Event',
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: Colors.blueGrey.shade600,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _showEventDialog(existingEvent: event),
                              ),
                              IconButton(
                                tooltip: 'Delete Event',
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                                onPressed: () => _confirmDeleteEvent(event),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        onPressed: () => _showEventDialog(),
        icon: const Icon(Icons.add),
        label: const Text(
          'New Event',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
