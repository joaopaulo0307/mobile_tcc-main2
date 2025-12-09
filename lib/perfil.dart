import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile_tcc/services/user_service.dart';
import 'package:mobile_tcc/services/theme_service.dart';
import 'package:provider/provider.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({
    super.key,
    String? userEmail,
    List<String>? tarefasRealizadas,
  });

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  File? _fotoPerfil;
  final TextEditingController descricaoController = TextEditingController();
  int tarefasVisiveis = 3;

  // Cores disponíveis para o tema
  final List<Color> _coresDisponiveis = [
    const Color(0xFF133A67), // Azul original
    const Color(0xFF2E7D32), // Verde
    const Color(0xFFC2185B), // Rosa
    const Color(0xFFF57C00), // Laranja
    const Color(0xFF7B1FA2), // Roxo
    const Color(0xFF0277BD), // Azul claro
    const Color(0xFFD32F2F), // Vermelho
    const Color(0xFF5D4037), // Marrom
  ];

  Future<void> _selecionarFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imagem = await picker.pickImage(source: ImageSource.gallery);
    if (imagem != null) {
      setState(() {
        _fotoPerfil = File(imagem.path);
      });
    }
  }

  void _alterarCorTema(Color novaCor, ThemeService themeService) {
    // Aqui você precisaria adicionar um método no ThemeService para mudar a cor primária
    // Por enquanto, vamos apenas notificar para demonstrar
    themeService.notifyListeners();
  }

  void _mostrarSelecaoCores(ThemeService themeService) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<ThemeService>( // ✅ CORRIGIDO: Usar ThemeService
          builder: (context, themeService, child) {
            final backgroundColor = themeService.backgroundColor;
            final textColor = themeService.textColor;
            final primaryColor = themeService.primaryColor;
            
            return AlertDialog(
              backgroundColor: backgroundColor,
              title: Text(
                'Escolha uma cor para o tema',
                style: TextStyle(color: textColor),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _coresDisponiveis.length,
                  itemBuilder: (context, index) {
                    final cor = _coresDisponiveis[index];
                    return GestureDetector(
                      onTap: () {
                        _alterarCorTema(cor, themeService); 
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: cor,
                          shape: BoxShape.circle,
                          border: primaryColor.value == cor.value
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: primaryColor.value == cor.value
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: textColor),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Inicializar com dados de exemplo se estiver vazio
    if (UserService.tarefasRealizadas.isEmpty) {
      UserService.initializeWithSampleData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTarefas = UserService.tarefasRealizadas.length;
    final mostrarTodas = tarefasVisiveis >= totalTarefas;

    return Consumer<ThemeService>( // ✅ CORRIGIDO: Usar ThemeService
      builder: (context, themeService, child) {
        final backgroundColor = themeService.backgroundColor;
        final cardColor = themeService.cardColor;
        final textColor = themeService.textColor;
        final secondaryTextColor = textColor.withOpacity(0.7);
        final primaryColor = themeService.primaryColor;
        final secondaryColor = themeService.secondaryColor;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: primaryColor,
            title: const Text(
              'MEU PERFIL',
              style: TextStyle(color: Colors.white),
            ),
            centerTitle: true,
            elevation: 4,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.palette, color: Colors.white),
                onPressed: () => _mostrarSelecaoCores(themeService),
                tooltip: 'Alterar cor do tema',
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Cabeçalho com foto e nome
                Container(
                  color: primaryColor.withOpacity(0.9),
                  padding: const EdgeInsets.only(top: 40, bottom: 30),
                  child: Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: _selecionarFoto,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[400],
                                backgroundImage:
                                    _fotoPerfil != null ? FileImage(_fotoPerfil!) : null,
                                child: _fotoPerfil == null
                                    ? const Icon(Icons.person, color: Colors.white, size: 40)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: secondaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                  onPressed: _selecionarFoto,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          UserService.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          UserService.userEmail,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            // TODO: Implementar gerenciamento de conta
                          },
                          child: const Text(
                            "Gerenciar sua conta",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Corpo
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Seção Estatísticas
                      _buildStatsCard(cardColor, textColor, primaryColor, secondaryColor),
                      const SizedBox(height: 20),

                      // Seção Sobre
                      _buildAboutSection(cardColor, textColor, secondaryTextColor, primaryColor),
                      const SizedBox(height: 20),

                      // Seção Tarefas Realizadas
                      _buildTarefasSection(
                        cardColor, 
                        textColor, 
                        secondaryTextColor, 
                        totalTarefas, 
                        mostrarTodas,
                        primaryColor,
                        secondaryColor
                      ),
                      const SizedBox(height: 20),

                      // Seção Descrição
                      _buildDescriptionSection(cardColor, textColor, secondaryTextColor, primaryColor),
                      const SizedBox(height: 30),

                      // Seção Personalização
                      _buildCustomizationSection(cardColor, textColor, themeService, primaryColor),
                      const SizedBox(height: 30),

                      // Rodapé
                      _buildFooter(textColor, secondaryTextColor, primaryColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(Color cardColor, Color textColor, Color primaryColor, Color secondaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Tarefas Concluídas', UserService.tarefasRealizadas.length.toString(), Icons.check_circle, primaryColor),
          _buildStatItem('Dias Ativo', '127', Icons.calendar_today, primaryColor),
          _buildStatItem('Pontos', '1.2K', Icons.emoji_events, primaryColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color primaryColor) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: primaryColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAboutSection(Color cardColor, Color textColor, Color secondaryTextColor, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                "Sobre",
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.email, 'E-mail', UserService.userEmail, secondaryTextColor),
          _buildInfoRow(Icons.date_range, 'Membro desde', 'Jan 2024', secondaryTextColor),
          _buildInfoRow(Icons.work, 'Tarefas preferidas', 'Organização', secondaryTextColor),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarefasSection(Color cardColor, Color textColor, Color secondaryTextColor, 
                              int totalTarefas, bool mostrarTodas, Color primaryColor, Color secondaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_history, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                "Tarefas Realizadas",
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Histórico das suas atividades concluídas",
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (UserService.tarefasRealizadas.isEmpty)
                  Text(
                    "Nenhuma tarefa realizada ainda",
                    style: TextStyle(color: secondaryTextColor),
                  ),
                for (int i = 0; i < (mostrarTodas ? totalTarefas : tarefasVisiveis); i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: secondaryColor, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            UserService.tarefasRealizadas[i],
                            style: TextStyle(color: textColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (totalTarefas > 3)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        tarefasVisiveis = mostrarTodas ? 3 : totalTarefas;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            mostrarTodas ? "Mostrar menos" : "Mostrar mais ($totalTarefas)",
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            mostrarTodas ? Icons.expand_less : Icons.expand_more,
                            color: primaryColor,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(Color cardColor, Color textColor, Color secondaryTextColor, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                "Descrição Pessoal",
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descricaoController,
            maxLines: 3,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: "Conte um pouco sobre você...",
              hintStyle: TextStyle(color: secondaryTextColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationSection(Color cardColor, Color textColor, ThemeService themeService, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                "Personalização",
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Tema atual:",
            style: TextStyle(color: textColor),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _mostrarSelecaoCores(themeService),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        themeService.isDarkMode ? "Modo Escuro" : "Modo Claro",
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: textColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Modo escuro", style: TextStyle(color: textColor)),
              Switch(
                value: themeService.isDarkMode,
                onChanged: (value) {
                  themeService.setDarkMode(value);
                },
                activeColor: primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Color textColor, Color secondaryTextColor, Color primaryColor) {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Image.asset('assets/logo.png', height: 40),
        const SizedBox(height: 16),
        Text(
          "Organize suas tarefas de forma simples",
          style: TextStyle(color: secondaryTextColor),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialIcon(FontAwesomeIcons.facebook, primaryColor),
            const SizedBox(width: 20),
            _buildSocialIcon(Icons.camera_alt, primaryColor),
            const SizedBox(width: 20),
            _buildSocialIcon(Icons.mail, primaryColor),
            const SizedBox(width: 20),
            _buildSocialIcon(FontAwesomeIcons.whatsapp, primaryColor),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          "© Todos os direitos reservados - 2025",
          style: TextStyle(color: secondaryTextColor, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, Color primaryColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: primaryColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}