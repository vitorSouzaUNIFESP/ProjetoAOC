# ==============================================================================
# PROJETO: SIMULADOR DE COFRE ELETRÔNICO (MIPS ASSEMBLY)
# AUTORES: Vitor Souza de Oliveira, Breno de Morais Gobato, Flavio Henrique Santos Ferreira
# 
# VERSÃO 3.0 (FINAL BOSS):
# - Cadastro Inicial com Confirmação.
# - Menu de Opções (Abrir ou Mudar Senha).
# - Troca de Senha (Exige: Atual + Nova + Confirmação).
# - Histórico, Bloqueio e Segurança Completa.
# ==============================================================================

.data
    # --- VARIÁVEIS DE DADOS ---
    senha_secreta:      .space 20      # A Senha Oficial
    buffer_confirmacao: .space 20      # Buffer auxiliar (Nova Senha Provisória)
    buffer_entrada:     .space 20      # Onde o usuário digita
    
    # --- VETOR DE HISTÓRICO ---
    historico:   .word 0, 0, 0, 0, 0   
    indice_hist: .word 0               

    # --- MENSAGENS DO SISTEMA ---
    msg_titulo:   .asciiz "\n--- COFRE ELETRONICO v3.0 ---\n"
    
    # Mensagens de Cadastro
    msg_cadastro: .asciiz "\n>>> CONFIGURACAO INICIAL <<<\n1. Crie a senha mestra (4 digitos): "
    msg_confirma: .asciiz "\n2. Confirme a senha mestra: "
    msg_difere:   .asciiz "\n[ERRO] As senhas nao batem! Tente novamente.\n"
    msg_salva:    .asciiz "\n[OK] Senha definida. Sistema pronto.\n"
    
    # Mensagens do Menu
    msg_menu:     .asciiz "\nESCOLHA UMA OPCAO:\n[1] Abrir Cofre\n[2] Mudar Senha\n> Opcao: "
    
    # Mensagens de Troca de Senha
    msg_troca_1:  .asciiz "\n[SEGURANCA] Digite a senha ATUAL: "
    msg_troca_2:  .asciiz "[NOVA] Digite a NOVA senha: "
    msg_troca_3:  .asciiz "[CONFIRMA] Digite a NOVA senha novamente: "
    msg_troca_ok: .asciiz "\n>>> SUCESSO: SENHA ALTERADA! <<<\n"
    
    # Mensagens de Uso Geral
    msg_pedir:    .asciiz "\nDigite a senha para abrir: "
    msg_sucesso:  .asciiz "\n>>> [ACESSO PERMITIDO] -- COFRE ABERTO <<<\n"
    msg_erro:     .asciiz "\n>>> [SENHA INCORRETA] <<<\n"
    msg_bloqueio: .asciiz "\n!!! SISTEMA BLOQUEADO - TENTATIVAS EXCEDIDAS !!!\n"
    msg_fim:      .asciiz "\nOperacao finalizada.\n"

.text
.globl main

main:
    li $v0, 4
    la $a0, msg_titulo
    syscall

# ==============================================================================
# 1. FASE DE CADASTRO 
# ==============================================================================
fase_cadastro:
    # A. Pede senha 1
    li $v0, 4
    la $a0, msg_cadastro
    syscall
    li $v0, 8
    la $a0, senha_secreta
    li $a1, 5
    syscall

    # B. Pede confirmação
    li $v0, 4
    la $a0, msg_confirma
    syscall
    li $v0, 8
    la $a0, buffer_confirmacao
    li $a1, 5
    syscall

    # C. Verifica se são iguais
    la $t0, senha_secreta
    la $t1, buffer_confirmacao
    jal comparar_strings_auxiliar # Função auxiliar que compara $t0 e $t1
    
    # Se $v0 retornou 0, as senhas são diferentes
    beq $v0, $zero, erro_cadastro
    
    # Sucesso
    li $v0, 4
    la $a0, msg_salva
    syscall
    
    # Zera contador de erros e vai para o menu
    li $s2, 0 
    j menu_principal

erro_cadastro:
    li $v0, 4
    la $a0, msg_difere
    syscall
    j fase_cadastro

# ==============================================================================
# 2. MENU PRINCIPAL
# ==============================================================================
menu_principal:
    # Mostra opções
    li $v0, 4
    la $a0, msg_menu
    syscall
    
    # Lê a opção (Lendo como Inteiro agora, syscall 5)
    li $v0, 5
    syscall
    move $t0, $v0 # Salva a opção em $t0
    
    # Decide para onde ir
    li $t1, 1
    beq $t0, $t1, modo_abrir_cofre   # Se digitou 1, vai abrir
    
    li $t1, 2
    beq $t0, $t1, modo_mudar_senha   # Se digitou 2, vai mudar senha
    
    j menu_principal # Se digitou outra coisa, repete o menu

# ==============================================================================
# OPÇÃO 1: ABRIR O COFRE 
# ==============================================================================
modo_abrir_cofre:
    # Pede senha
    li $v0, 4
    la $a0, msg_pedir
    syscall
    
    # Lê entrada
    li $v0, 8
    la $a0, buffer_entrada
    li $a1, 5
    syscall
    
    # Valida
    jal validar_senha
    
    # Grava Histórico - Log's
    move $s1, $v0
    move $a0, $s1
    jal registrar_historico
    
    # Verifica resultado
    beq $s1, $zero, erro_abrir
    
    # Sucesso ao abrir
    li $v0, 4
    la $a0, msg_sucesso
    syscall
    j fim_programa

erro_abrir:
    li $v0, 4
    la $a0, msg_erro
    syscall
    addi $s2, $s2, 1       # Erro++
    li $t9, 5
    beq $s2, $t9, sistema_bloqueado
    j menu_principal       # Volta para o menu (não pede senha direto)

# ==============================================================================
# OPÇÃO 2: MUDAR A SENHA
# ==============================================================================
modo_mudar_senha:
    # PASSO 1: Pedir a senha ATUAL para autorizar
    li $v0, 4
    la $a0, msg_troca_1
    syscall
    
    li $v0, 8
    la $a0, buffer_entrada
    li $a1, 5
    syscall
    
    # Valida a senha atual
    jal validar_senha
    beq $v0, $zero, erro_troca_senha # Se errou a atual, cancela
    
    # PASSO 2: Pedir a NOVA senha
    li $v0, 4
    la $a0, msg_troca_2
    syscall
    
    # Guardamos a nova senha no 'buffer_confirmacao' temporariamente
    li $v0, 8
    la $a0, buffer_confirmacao 
    li $a1, 5
    syscall
    
    # PASSO 3: Confirmar a NOVA senha
    li $v0, 4
    la $a0, msg_troca_3
    syscall
    
    # Guardamos a confirmação no 'buffer_entrada'
    li $v0, 8
    la $a0, buffer_entrada 
    li $a1, 5
    syscall
    
    # PASSO 4: Comparar Nova vs Confirmação
    la $t0, buffer_confirmacao
    la $t1, buffer_entrada
    jal comparar_strings_auxiliar
    
    beq $v0, $zero, erro_troca_divergente # Se não baterem, erro
    
    # PASSO 5: SUCESSO! Copiar a nova senha para a variável oficial
    # Precisamos copiar de 'buffer_confirmacao' para 'senha_secreta'
    jal copiar_senha_nova
    
    li $v0, 4
    la $a0, msg_troca_ok
    syscall
    
    j menu_principal # Volta pro menu com a senha nova já valendo

erro_troca_senha:
    li $v0, 4
    la $a0, msg_erro
    syscall
    j menu_principal

erro_troca_divergente:
    li $v0, 4
    la $a0, msg_difere
    syscall
    j menu_principal

# ==============================================================================
# FINAL E BLOQUEIO
# ==============================================================================
sistema_bloqueado:
    li $v0, 4
    la $a0, msg_bloqueio
    syscall
    j fim_programa

fim_programa:
    li $v0, 4
    la $a0, msg_fim
    syscall
    li $v0, 10
    syscall

# ==============================================================================
# FUNÇÕES DE LÓGICA
# ==============================================================================

# Valida se buffer_entrada == senha_secreta
validar_senha:
    la $t0, senha_secreta
    la $t1, buffer_entrada
    j comparar_strings_auxiliar # Pula para a logica de comparacao

# Compara duas strings cujos endereços estão em $t0 e $t1
# Retorna 1 (Igual) ou 0 (Diferente) em $v0
comparar_strings_auxiliar:
    li $t2, 4
loop_comp:
    lb $t3, 0($t0)
    lb $t4, 0($t1)
    bne $t3, $t4, retorno_falso
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    addi $t2, $t2, -1
    bgtz $t2, loop_comp
    li $v0, 1
    jr $ra
retorno_falso:
    li $v0, 0
    jr $ra

# Grava no histórico (Circular)
registrar_historico:
    addi $sp, $sp, -4
    sw   $s0, 0($sp)
    la   $t0, indice_hist
    lw   $t1, 0($t0)
    mul  $t2, $t1, 4
    la   $s0, historico
    add  $s0, $s0, $t2
    sw   $a0, 0($s0)
    addi $t1, $t1, 1
    li   $t3, 5
    bne  $t1, $t3, salva_ind
    li   $t1, 0
salva_ind:
    sw   $t1, 0($t0)
    lw   $s0, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# Copia bytes de 'buffer_confirmacao' para 'senha_secreta'
copiar_senha_nova:
    la $t0, buffer_confirmacao # Origem (Nova Senha)
    la $t1, senha_secreta      # Destino (Variavel Oficial)
    li $t2, 4                  # 4 Bytes
loop_copia:
    lb $t3, 0($t0)             # Pega byte da origem
    sb $t3, 0($t1)             # Salva byte no destino (SB = Store Byte)
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    addi $t2, $t2, -1
    bgtz $t2, loop_copia
    jr $ra
