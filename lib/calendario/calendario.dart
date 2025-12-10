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
import '../lista_compras.dart';

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
  
  // Controle para adicionar tarefas
  final TextEditingController _tarefaController = TextEditingController();
  final TextEditingController _descricaoTarefaController = TextEditingController();
  DateTime? _dataVencimentoTarefa;
  String _prioridadeTarefa = 'media';
  String? _responsavelTarefa;

  // Lista de tarefas (agora carregada do Firestore)
  List<Map<String, dynamic>> _tarefas = [];

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
        await _loadTarefas(); // Carregar tarefas do Firestore
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
          'criadoPorNome': eventData['criadoPorNome'] ?? '',
          'criadoEm': (eventData['criadoEm'] as Timestamp).toDate(),
          'casaId': eventData['casaId'] ?? '',
        });
      }
      
      setState(() {
        _events = eventsMap;
        _selectedEvents = _getEventsForDay(_selectedDay!);
      });
      
    } catch (e) {
      print('❌ Erro ao carregar eventos: $e');
      _mostrarErro('Erro ao carregar eventos: ${e.toString()}');
    }
  }

  Future<void> _loadTarefas() async {
    if (_currentHouseId == null) return;

    try {
      // Carregar tarefas para hoje
      final hoje = DateTime.now();
      final inicioDoDia = DateTime(hoje.year, hoje.month, hoje.day);
      final fimDoDia = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);
      
      final tarefasSnapshot = await _firestore
          .collection('casas')
          .doc(_currentHouseId!)
          .collection('tarefas')
          .where('dataVencimento', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDoDia))
          .where('dataVencimento', isLessThanOrEqualTo: Timestamp.fromDate(fimDoDia))
          .orderBy('dataVencimento')
          .get();

      setState(() {
        _tarefas = tarefasSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'titulo': data['titulo'] ?? '',
            'descricao': data['descricao'] ?? '',
            'dataVencimento': (data['dataVencimento'] as Timestamp).toDate(),
            'prioridade': data['prioridade'] ?? 'media',
            'concluida': data['concluida'] ?? false,
            'criadoPor': data['criadoPor'] ?? '',
            'criadoPorNome': data['criadoPorNome'] ?? '',
          };
        }).toList();
      });
      
    } catch (e) {
      print('❌ Erro ao carregar tarefas: $e');
      // Não mostra erro se for apenas falta de permissões
      if (!e.toString().contains('permission-denied')) {
        _mostrarErro('Erro ao carregar tarefas: ${e.toString()}');
      }
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
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
    if (_eventController.text.isEmpty || _currentHouseId == null) {
      _mostrarErro('Preencha o título do evento');
      return;
    }
    
    final user = _auth.currentUser;
    if (user == null) {
      _mostrarErro('Usuário não autenticado');
      return;
    }
    
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
            'casaNome': _currentHouseName ?? 'Casa Atual',
          });
      
      _eventController.clear();
      _descricaoController.clear();
      
      await _loadEvents();
      
      if (context.mounted) {
        Navigator.of(context).pop();
        _mostrarSucesso('✅ Evento adicionado com sucesso!');
      }
      
    } catch (e) {
      print('❌ Erro ao adicionar evento: $e');
      if (context.mounted) {
        _mostrarErro('Erro ao adicionar evento: ${e.toString()}');
      }
    }
  }

  void _showAddTarefaDialog() {
    _tarefaController.clear();
    _descricaoTarefaController.clear();
    _dataVencimentoTarefa = _selectedDay;
    _prioridadeTarefa = 'media';
    _responsavelTarefa = null;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text(
              'Adicionar Tarefa',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _tarefaController,
                    decoration: const InputDecoration(
                      labelText: 'Título da tarefa',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.task),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descricaoTarefaController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  // Seletor de data de vencimento
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _dataVencimentoTarefa ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null && picked != _dataVencimentoTarefa) {
                        setState(() => _dataVencimentoTarefa = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            _dataVencimentoTarefa != null
                                ? DateFormat('dd/MM/yyyy').format(_dataVencimentoTarefa!)
                                : 'Selecione a data de vencimento',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Seletor de prioridade
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Prioridade:'),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile(
                              title: const Text('Baixa'),
                              value: 'baixa',
                              groupValue: _prioridadeTarefa,
                              onChanged: (value) {
                                setState(() => _prioridadeTarefa = value.toString());
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile(
                              title: const Text('Média'),
                              value: 'media',
                              groupValue: _prioridadeTarefa,
                              onChanged: (value) {
                                setState(() => _prioridadeTarefa = value.toString());
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile(
                              title: const Text('Alta'),
                              value: 'alta',
                              groupValue: _prioridadeTarefa,
                              onChanged: (value) {
                                setState(() => _prioridadeTarefa = value.toString());
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
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
                onPressed: () {
                  Navigator.of(context).pop();
                  _addTarefa();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Adicionar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addTarefa() async {
    if (_tarefaController.text.isEmpty || _currentHouseId == null) {
      _mostrarErro('Preencha o título da tarefa');
      return;
    }
    
    if (_dataVencimentoTarefa == null) {
      _mostrarErro('Selecione uma data de vencimento');
      return;
    }
    
    final user = _auth.currentUser;
    if (user == null) {
      _mostrarErro('Usuário não autenticado');
      return;
    }
    
    try {
      await _firestore
          .collection('casas')
          .doc(_currentHouseId!)
          .collection('tarefas')
          .add({
            'titulo': _tarefaController.text,
            'descricao': _descricaoTarefaController.text,
            'dataCriacao': Timestamp.now(),
            'dataVencimento': Timestamp.fromDate(_dataVencimentoTarefa!),
            'prioridade': _prioridadeTarefa,
            'concluida': false,
            'criadoPor': user.uid,
            'criadoPorNome': user.email?.split('@')[0] ?? 'Usuário',
            'casaId': _currentHouseId,
            'casaNome': _currentHouseName ?? 'Casa Atual',
          });
      
      _tarefaController.clear();
      _descricaoTarefaController.clear();
      
      await _loadTarefas(); // Recarregar tarefas após adicionar
      
      _mostrarSucesso('✅ Tarefa adicionada com sucesso!');
      
    } catch (e) {
      print('❌ Erro ao adicionar tarefa: $e');
      _mostrarErro('Erro ao adicionar tarefa: ${e.toString()}');
    }
  }

  // Método para atualizar o status da tarefa
  Future<void> _updateTarefaStatus(String tarefaId, bool concluida) async {
    if (_currentHouseId == null) return;
    
    try {
      await _firestore
          .collection('casas')
          .doc(_currentHouseId!)
          .collection('tarefas')
          .doc(tarefaId)
          .update({
            'concluida': concluida,
            'dataConclusao': concluida ? Timestamp.now() : null,
          });
      
      // Atualizar a lista local
      setState(() {
        final index = _tarefas.indexWhere((tarefa) => tarefa['id'] == tarefaId);
        if (index != -1) {
          _tarefas[index]['concluida'] = concluida;
        }
      });
      
      _mostrarSucesso('Tarefa ${concluida ? 'concluída' : 'reaberta'}!');
      
    } catch (e) {
      print('❌ Erro ao atualizar tarefa: $e');
      _mostrarErro('Erro ao atualizar tarefa: ${e.toString()}');
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
    return Drawer(
      child: Container(
        color: const Color(0xFF2D2D2D),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.blue,
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.blue, size: 30),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _auth.currentUser?.email?.split('@')[0] ?? 'Usuário',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _auth.currentUser?.email ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.attach_money,
                    title: 'Econômico',
                    onTap: () => _navigateToEconomico(context),
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_today,
                    title: 'Calendário',
                    onTap: () => Navigator.pop(context),
                    isSelected: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.people,
                    title: 'Usuários',
                    onTap: () => _navigateTo(context, const Usuarios()),
                  ),
                  _buildDrawerItem(
                    icon: Icons.shopping_cart,
                    title: 'Lista de compras',
                    onTap: () => _navigateTo(context, const ListaCompras()),
                  ),
                  const Divider(color: Colors.grey),
                  _buildDrawerItem(
                    icon: Icons.house,
                    title: 'Minhas Casas',
                    onTap: () => _navigateToHome(context),
                  ),
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: 'Meu Perfil',
                    onTap: () => _navigateTo(context, const PerfilPage()),
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Configurações',
                    onTap: () => _navigateTo(context, const ConfigPage()),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: () => _logout(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sair'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : Colors.white),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
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
          SnackBar(content: Text('Erro ao fazer logout: $e')),
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
      title: const Text(
        'Calendário',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_task, color: Colors.white),
          onPressed: _showAddTarefaDialog,
          tooltip: 'Adicionar Tarefa',
        ),
        IconButton(
          icon: const Icon(Icons.event, color: Colors.white),
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
    // Cabeçalho do calendário (mês atual)
    final monthYear = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay);
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título "Calendário"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Calendário',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Mês atual
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[700]!, width: 1)),
            ),
            child: Text(
              monthYear[0].toUpperCase() + monthYear.substring(1), // Capitalizar primeira letra
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Dias da semana (header)
          Container(
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              onFormatChanged: (format) => setState(() => _calendarFormat = format),
              onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
              eventLoader: (day) => _getEventsForDay(day),
              
              // Estilo simplificado como na imagem
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
                markersMaxCount: 1,
                markerDecoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                markerSize: 4,
                tablePadding: EdgeInsets.zero,
                cellPadding: EdgeInsets.zero,
              ),
              
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                weekendStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey)),
                ),
              ),
              
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: false,
                titleTextStyle: TextStyle(fontSize: 0), // Esconder título padrão
                leftChevronVisible: false,
                rightChevronVisible: false,
                headerPadding: EdgeInsets.zero,
                headerMargin: EdgeInsets.zero,
              ),
              
              rowHeight: 40,
              daysOfWeekHeight: 40,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DIAS DA SEMANA ====================
  Widget _buildDiasDaSemana() {
    final diasDaSemana = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    
    // Pegar a semana atual baseada no dia selecionado
    final startOfWeek = _selectedDay!.subtract(Duration(days: _selectedDay!.weekday));
    final semanaAtual = {
      'Dom': startOfWeek.add(const Duration(days: 0)).day,
      'Seg': startOfWeek.add(const Duration(days: 1)).day,
      'Ter': startOfWeek.add(const Duration(days: 2)).day,
      'Qua': startOfWeek.add(const Duration(days: 3)).day,
      'Qui': startOfWeek.add(const Duration(days: 4)).day,
      'Sex': startOfWeek.add(const Duration(days: 5)).day,
      'Sáb': startOfWeek.add(const Duration(days: 6)).day,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Cabeçalho dos dias da semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: diasDaSemana.map((dia) {
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[700]!)),
                  ),
                  child: Text(
                    dia,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 8),
          
          // Números dos dias (semana atual)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: diasDaSemana.map((dia) {
              final numeroDia = semanaAtual[dia] ?? 0;
              final isToday = _isToday(startOfWeek.add(Duration(days: diasDaSemana.indexOf(dia))));
              
              return Expanded(
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  child: Text(
                    numeroDia.toString(),
                    style: TextStyle(
                      color: isToday ? Colors.blue : Colors.white,
                      fontSize: 14,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  // ==================== LISTA DE TAREFAS ====================
  Widget _buildListaTarefas() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título das tarefas
          const Text(
            'Tarefas de Hoje',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_tarefas.isEmpty)
            // Estado vazio
            _buildEstadoVazio()
          else
            // Lista de tarefas reais
            ..._tarefas.map((tarefa) {
              final bool isConcluida = tarefa['concluida'] as bool;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // Bolinha azul como na imagem
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (tarefa['titulo'] as String).toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              decoration: isConcluida 
                                  ? TextDecoration.lineThrough 
                                  : TextDecoration.none,
                            ),
                          ),
                          if (tarefa['descricao'] != null && (tarefa['descricao'] as String).isNotEmpty)
                            Text(
                              tarefa['descricao'] as String,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Checkbox para marcar como concluído
                    Checkbox(
                      value: isConcluida,
                      onChanged: (value) {
                        _updateTarefaStatus(tarefa['id'] as String, value ?? false);
                      },
                      checkColor: Colors.white,
                      fillColor: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                          return isConcluida ? Colors.green : Colors.grey;
                        },
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        
          // Separador
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            height: 1,
            color: Colors.grey[700],
          ),
        
          // Exemplo (apenas se não houver tarefas)
          if (_tarefas.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Exemplo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Organize suas tarefas de forma simples',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEstadoVazio() {
    return Column(
      children: [
        // Exemplo de tarefas (como na imagem)
        _buildTarefaExemplo('PASSEAR COM O CACHORRO'),
        _buildTarefaExemplo('COMPRAR ARROZ'),
        _buildTarefaExemplo('TIRAR O LIXO'),
        const SizedBox(height: 16),
        
        // Botão para adicionar tarefa
        ElevatedButton.icon(
          onPressed: _showAddTarefaDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            minimumSize: const Size(double.infinity, 40),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Adicionar Tarefa'),
        ),
      ],
    );
  }

  Widget _buildTarefaExemplo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
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
        children: [
          Text(
            _currentHouseName ?? 'Organize suas tarefas de forma simples',
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          // Emojis como na imagem
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: Colors.yellow, size: 16),
              SizedBox(width: 8),
              Icon(Icons.bedtime, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Icon(Icons.flash_on, color: Colors.orange, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "© Todos os direitos reservados - 2025",
            style: TextStyle(color: Colors.white70, fontSize: 11),
            textAlign: TextAlign.center,
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      drawer: _buildDrawer(context, Provider.of<ThemeService>(context)),
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Calendário
                  _buildCalendar(),
                  
                  // Dias da semana (conforme imagem)
                  _buildDiasDaSemana(),
                  
                  // Lista de tarefas (conforme imagem)
                  _buildListaTarefas(),
                  
                  // Eventos do dia selecionado
                  if (_selectedEvents.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Eventos do Dia',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._selectedEvents.map((event) {
                            return ListTile(
                              leading: const Icon(Icons.event, color: Colors.blue),
                              title: Text(
                                event['titulo'] as String,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: event['descricao'] != null && (event['descricao'] as String).isNotEmpty
                                  ? Text(
                                      event['descricao'] as String,
                                      style: const TextStyle(color: Colors.grey),
                                    )
                                  : null,
                            );
                          }),
                        ],
                      ),
                    ),
                  
                  // Footer
                  _buildFooter(),
                ],
              ),
            ),
    );
  }
}