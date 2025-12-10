import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';
import '../meu_casas.dart';
import '../usuarios.dart';
import '../perfil.dart';
import '../config.dart';
import '../economic/economico.dart';
import '../home.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> _selectedEvents = [];
  final TextEditingController _eventController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentHouseId;
  String? _currentHouseName;
  bool _isLoading = true;
  
  // Novo estado para gerenciamento de tarefas
  List<Map<String, dynamic>> _tarefas = [];
  List<Map<String, dynamic>> _tarefasSelecionadas = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadCurrentHouse();
  }

  Future<void> _loadCurrentHouse() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Buscar todas as casas onde o usuário é membro
      final housesSnapshot = await _firestore
          .collection('casas')
          .where('membros.${user.uid}', isNotEqualTo: null)
          .get();

      if (housesSnapshot.docs.isNotEmpty) {
        // Selecionar a primeira casa
        final houseDoc = housesSnapshot.docs.first;
        final houseData = houseDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _currentHouseId = houseDoc.id;
          _currentHouseName = houseData['nome'] ?? 'Minha Casa';
        });
        
        await _loadEvents();
        await _loadTarefas();
      }
      
      setState(() => _isLoading = false);
      
    } catch (e) {
      print('❌ Erro ao carregar casa: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEvents() async {
    if (_currentHouseId == null) return;

    try {
      final eventosSnapshot = await _firestore
          .collection('casas')
          .doc(_currentHouseId!)
          .collection('eventos')
          .orderBy('data', descending: false)
          .get();

      Map<DateTime, List<Map<String, dynamic>>> eventsMap = {};
      
      for (var doc in eventosSnapshot.docs) {
        final eventData = doc.data();
        final data = (eventData['data'] as Timestamp).toDate();
        final day = DateTime(data.year, data.month, data.day);
        
        if (!eventsMap.containsKey(day)) {
          eventsMap[day] = [];
        }
        
        eventsMap[day]!.add({
          'id': doc.id,
          'titulo': eventData['titulo'] ?? '',
          'descricao': eventData['descricao'] ?? '',
          'data': data,
          'criadoPor': eventData['criadoPor'] ?? '',
          'criadoEm': (eventData['criadoEm'] as Timestamp).toDate(),
          'tipo': 'evento',
        });
      }
      
      setState(() {
        _events = eventsMap;
        _selectedEvents = _getEventsForDay(_selectedDay!);
      });
      
    } catch (e) {
      print('❌ Erro ao carregar eventos: $e');
    }
  }

  Future<void> _loadTarefas() async {
    if (_currentHouseId == null) return;

    try {
      final tarefasSnapshot = await _firestore
          .collection('casas')
          .doc(_currentHouseId!)
          .collection('tarefas')
          .orderBy('dataCriacao', descending: false)
          .get();

      List<Map<String, dynamic>> tarefasList = [];
      
      for (var doc in tarefasSnapshot.docs) {
        final tarefaData = doc.data();
        final dataCriacao = (tarefaData['dataCriacao'] as Timestamp).toDate();
        final dataVencimento = tarefaData['dataVencimento'] != null 
            ? (tarefaData['dataVencimento'] as Timestamp).toDate()
            : null;
        
        tarefasList.add({
          'id': doc.id,
          'titulo': tarefaData['titulo'] ?? '',
          'descricao': tarefaData['descricao'] ?? '',
          'dataCriacao': dataCriacao,
          'dataVencimento': dataVencimento,
          'prioridade': tarefaData['prioridade'] ?? 'media',
          'concluida': tarefaData['concluida'] ?? false,
          'criadoPor': tarefaData['criadoPor'] ?? '',
          'responsavel': tarefaData['responsavel'] ?? '',
          'tipo': 'tarefa',
        });
      }
      
      setState(() {
        _tarefas = tarefasList;
        _tarefasSelecionadas = _getTarefasForDay(_selectedDay!);
      });
      
    } catch (e) {
      print('❌ Erro ao carregar tarefas: $e');
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  List<Map<String, dynamic>> _getTarefasForDay(DateTime day) {
    return _tarefas.where((tarefa) {
      final dataVencimento = tarefa['dataVencimento'] as DateTime?;
      if (dataVencimento == null) return false;
      
      return dataVencimento.year == day.year &&
             dataVencimento.month == day.month &&
             dataVencimento.day == day.day;
    }).toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
        _tarefasSelecionadas = _getTarefasForDay(selectedDay);
      });
    }
  }

  void _showAddEventDialog() {
    _eventController.clear();
    _descricaoController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Adicionar Evento',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _eventController,
                decoration: const InputDecoration(
                  labelText: 'Título do evento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(height: 8),
                    Text(
                      'Data: ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'O evento será visível para todos os membros da casa',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => _addEvent(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addEvent() async {
    if (_eventController.text.isEmpty || _currentHouseId == null) return;
    
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      await _firestore
          .collection('casas')
          .doc(_currentHouseId!)
          .collection('eventos')
          .add({
            'titulo': _eventController.text,
            'descricao': _descricaoController.text,
            'data': Timestamp.fromDate(_selectedDay!),
            'criadoPor': user.uid,
            'criadoPorNome': user.email?.split('@')[0] ?? 'Usuário',
            'criadoEm': Timestamp.now(),
            'casaId': _currentHouseId,
            'casaNome': _currentHouseName,
          });
      
      _eventController.clear();
      _descricaoController.clear();
      
      await _loadEvents();
      
      if (context.mounted) {
        Navigator.of(context).pop();
        _mostrarSucesso('Evento adicionado com sucesso!');
      }
      
    } catch (e) {
      print('❌ Erro ao adicionar evento: $e');
      if (context.mounted) {
        _mostrarErro('Erro ao adicionar evento: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    if (_currentHouseId == null) return;
    
    try {
      await _firestore
          .collection('casas')
          .doc(_currentHouseId!)
          .collection('eventos')
          .doc(eventId)
          .delete();
      
      await _loadEvents();
      _mostrarSucesso('Evento removido com sucesso!');
      
    } catch (e) {
      print('❌ Erro ao remover evento: $e');
      _mostrarErro('Erro ao remover evento: ${e.toString()}');
    }
  }

  Future<void> _concluirTarefa(String tarefaId) async {
    if (_currentHouseId == null) return;
    
    try {
      await _firestore
          .collection('casas')
          .doc(_currentHouseId!)
          .collection('tarefas')
          .doc(tarefaId)
          .update({
            'concluida': true,
            'dataConclusao': Timestamp.now(),
          });
      
      await _loadTarefas();
      _mostrarSucesso('Tarefa concluída!');
      
    } catch (e) {
      print('❌ Erro ao concluir tarefa: $e');
      _mostrarErro('Erro ao concluir tarefa: ${e.toString()}');
    }
  }

  void _mostrarSucesso(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarErro(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ==================== DRAWER ====================
  Widget _buildDrawer(BuildContext context, ThemeService themeService) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final user = _auth.currentUser;

    return Drawer(
      backgroundColor: backgroundColor,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).primaryColor,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white,
                    child: Text(
                      user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.email?.split('@')[0] ?? 'Usuário',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.attach_money,
                  title: 'Econômico',
                  textColor: textColor,
                  onTap: () => _navigateToEconomico(context),
                ),
                _buildDrawerItem(
                  icon: Icons.calendar_today,
                  title: 'Calendário',
                  textColor: textColor,
                  onTap: () {
                    Navigator.pop(context);
                  },
                  isSelected: true,
                ),
                _buildDrawerItem(
                  icon: Icons.people,
                  title: 'Usuários',
                  textColor: textColor,
                  onTap: () => _navigateTo(context, const Usuarios()),
                ),
                Divider(color: Theme.of(context).dividerColor),
                _buildDrawerItem(
                  icon: Icons.house,
                  title: 'Minhas Casas',
                  textColor: textColor,
                  onTap: () => _navigateToHome(context),
                ),
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'Meu Perfil',
                  textColor: textColor,
                  onTap: () => _navigateTo(context, const PerfilPage()),
                ),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'Configurações',
                  textColor: textColor,
                  onTap: () => _navigateTo(context, const ConfigPage()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => _logout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Sair'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required Color textColor,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : textColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.blue : textColor,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue, size: 16) : null,
      onTap: onTap,
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF2D2D2D),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calendário',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _currentHouseName ?? 'Casa Atual',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: _showAddEventDialog,
          tooltip: 'Adicionar Evento',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () {
            _loadEvents();
            _loadTarefas();
          },
          tooltip: 'Atualizar',
        ),
      ],
    );
  }

  // ==================== CALENDÁRIO ====================
  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        eventLoader: (day) {
          final events = _getEventsForDay(day);
          final tarefas = _getTarefasForDay(day);
          return List.generate(events.length + tarefas.length, (index) => index);
        },
        
        // Estilização personalizada
        calendarStyle: CalendarStyle(
          defaultTextStyle: const TextStyle(color: Colors.white),
          weekendTextStyle: const TextStyle(color: Colors.white),
          selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          todayTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          todayDecoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 2),
          ),
          selectedDecoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          outsideDaysVisible: false,
          markersAutoAligned: true,
          markerDecoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
          markerSize: 6,
          markerMargin: const EdgeInsets.symmetric(horizontal: 1),
          cellMargin: const EdgeInsets.all(2),
          cellPadding: const EdgeInsets.all(4),
        ),
        
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          weekendStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            border: Border.all(color: Colors.blue),
            borderRadius: BorderRadius.circular(8),
          ),
          formatButtonTextStyle: const TextStyle(color: Colors.white),
          titleCentered: true,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
          headerPadding: const EdgeInsets.symmetric(vertical: 8),
          headerMargin: const EdgeInsets.only(bottom: 16),
        ),
        
        // Dias da semana em português
        daysOfWeekHeight: 40,
        rowHeight: 50,
      ),
    );
  }

  // ==================== LISTA DE EVENTOS DO DIA ====================
  Widget _buildEventosDoDia() {
    final totalItens = _selectedEvents.length + _tarefasSelecionadas.length;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${DateFormat('dd/MM/yyyy').format(_selectedDay!)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalItens ${totalItens == 1 ? 'item' : 'itens'}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (totalItens == 0)
            _buildEmptyState()
          else
            Column(
              children: [
                // Eventos
                if (_selectedEvents.isNotEmpty) ...[
                  _buildSectionTitle('🎯 Eventos', _selectedEvents.length),
                  const SizedBox(height: 8),
                  ..._selectedEvents.map((event) => _buildEventoItem(event)),
                ],
                
                // Tarefas
                if (_tarefasSelecionadas.isNotEmpty) ...[
                  if (_selectedEvents.isNotEmpty) const SizedBox(height: 16),
                  _buildSectionTitle('📝 Tarefas', _tarefasSelecionadas.length),
                  const SizedBox(height: 8),
                  ..._tarefasSelecionadas.map((tarefa) => _buildTarefaItem(tarefa)),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventoItem(Map<String, dynamic> event) {
    return Card(
      color: const Color(0xFF3A3A3A),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.event, color: Colors.blue, size: 20),
        ),
        title: Text(
          event['titulo'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: event['descricao'] != null && event['descricao'].isNotEmpty
            ? Text(
                event['descricao'],
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: () => _showDeleteDialog(event['id']),
        ),
        onTap: () => _showEventDetails(event),
      ),
    );
  }

  Widget _buildTarefaItem(Map<String, dynamic> tarefa) {
    final prioridade = tarefa['prioridade'] as String;
    Color prioridadeColor = Colors.grey;
    
    switch (prioridade) {
      case 'alta':
        prioridadeColor = Colors.red;
        break;
      case 'media':
        prioridadeColor = Colors.orange;
        break;
      case 'baixa':
        prioridadeColor = Colors.green;
        break;
    }
    
    return Card(
      color: const Color(0xFF3A3A3A),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: prioridadeColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.task,
            color: prioridadeColor,
            size: 20,
          ),
        ),
        title: Text(
          tarefa['titulo'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tarefa['descricao'] != null && tarefa['descricao'].isNotEmpty)
              Text(
                tarefa['descricao'],
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (tarefa['responsavel'] != null && tarefa['responsavel'].isNotEmpty)
              Text(
                'Responsável: ${tarefa['responsavel']}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: prioridadeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                prioridade.toUpperCase(),
                style: TextStyle(
                  color: prioridadeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
              onPressed: () => _showConcluirTarefaDialog(tarefa['id']),
              tooltip: 'Concluir Tarefa',
            ),
          ],
        ),
        onTap: () => _showTarefaDetails(tarefa),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.event_note,
            color: Colors.grey[600],
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum evento ou tarefa para esta data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Clique no botão + para adicionar um evento',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddEventDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar Evento'),
          ),
        ],
      ),
    );
  }

  // ==================== SEÇÕES FIXAS ====================
  Widget _buildFixedSections() {
    return Column(
      children: [
        // Seção de dias da semana (estilizado como na imagem)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta Semana',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _buildDiasDaSemana(),
              ),
            ],
          ),
        ),

        // Seção de resumo
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resumo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildResumoItem('Eventos do mês', _events.length.toString()),
              _buildResumoItem('Tarefas pendentes', _tarefas.where((t) => !t['concluida']).length.toString()),
              _buildResumoItem('Tarefas de hoje', _tarefasSelecionadas.length.toString()),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDiasDaSemana() {
    final hoje = DateTime.now();
    final diasDaSemana = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    final numerosDaSemana = List.generate(7, (index) {
      final dia = hoje.subtract(Duration(days: hoje.weekday - index));
      return dia.day.toString();
    });

    return List.generate(7, (index) {
      final isToday = index == hoje.weekday;
      
      return Column(
        children: [
          Text(
            diasDaSemana[index],
            style: TextStyle(
              color: isToday ? Colors.blue : Colors.grey[400],
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isToday ? Colors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: isToday ? null : Border.all(color: Colors.grey[600]!),
            ),
            child: Center(
              child: Text(
                numerosDaSemana[index],
                style: TextStyle(
                  color: isToday ? Colors.white : Colors.grey[400],
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildResumoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FOOTER ====================
  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF2D2D2D),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currentHouseName ?? 'Organize suas tarefas de forma simples',
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            "© Todos os direitos reservados - 2025",
            style: TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==================== DIALOGS ====================
  void _showDeleteDialog(String eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Evento'),
        content: const Text('Tem certeza que deseja remover este evento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteEvent(eventId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _showConcluirTarefaDialog(String tarefaId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concluir Tarefa'),
        content: const Text('Tem certeza que deseja marcar esta tarefa como concluída?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _concluirTarefa(tarefaId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
  }

  void _showEventDetails(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event['titulo']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event['descricao'] != null && event['descricao'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    event['descricao'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              Text(
                'Data: ${DateFormat('dd/MM/yyyy').format(event['data'])}',
                style: const TextStyle(fontSize: 14),
              ),
              if (event['criadoEm'] != null)
                Text(
                  'Criado em: ${DateFormat('dd/MM/yyyy HH:mm').format(event['criadoEm'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showTarefaDetails(Map<String, dynamic> tarefa) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tarefa['titulo']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tarefa['descricao'] != null && tarefa['descricao'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    tarefa['descricao'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              if (tarefa['dataVencimento'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Vencimento: ${DateFormat('dd/MM/yyyy').format(tarefa['dataVencimento'])}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              if (tarefa['responsavel'] != null && tarefa['responsavel'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Responsável: ${tarefa['responsavel']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              Text(
                'Status: ${tarefa['concluida'] ? 'Concluída' : 'Pendente'}',
                style: TextStyle(
                  fontSize: 14,
                  color: tarefa['concluida'] ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
          if (!tarefa['concluida'])
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showConcluirTarefaDialog(tarefa['id']);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Concluir'),
            ),
        ],
      ),
    );
  }

  // ==================== NAVEGAÇÃO ====================
  void _navigateTo(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  void _navigateToEconomico(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Economico(
          casa: {
            'nome': _currentHouseName ?? 'Casa Atual',
            'id': _currentHouseId ?? '1',
          },
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MeuCasas()),
      (route) => false,
    );
  }

  // ==================== BUILD PRINCIPAL ====================
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          drawer: _buildDrawer(context, themeService),
          appBar: _buildAppBar(context),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendário
                      _buildCalendar(),
                      
                      // Eventos do dia selecionado
                      _buildEventosDoDia(),
                      
                      // Seções fixas
                      _buildFixedSections(),
                      
                      // Footer
                      _buildFooter(),
                    ],
                  ),
                ),
          // Botão flutuante para adicionar evento
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddEventDialog,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}