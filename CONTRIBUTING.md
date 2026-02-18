# 🤝 Guide de Contribution - Vision360

Merci de votre intérêt pour contribuer au projet Vision360 ! Ce guide explique comment participer efficacement au développement.

## Table des matières

- [Code de conduite](#code-de-conduite)
- [Comment contribuer](#comment-contribuer)
- [Standards de code](#standards-de-code)
- [Processus de Pull Request](#processus-de-pull-request)
- [Structure du projet](#structure-du-projet)

## Code de conduite

Ce projet est un projet académique (SAE) et toute contribution doit respecter :
- Le respect mutuel entre contributeurs
- L'accessibilité comme valeur centrale
- La qualité du code et de la documentation

## Comment contribuer

### Signaler un bug

1. Vérifier que le bug n'est pas déjà signalé dans les Issues
2. Créer une Issue avec :
   - Titre clair et descriptif
   - Étapes pour reproduire
   - Comportement attendu vs observé
   - Environnement (OS, navigateur, versions)
   - Screenshots si pertinent

### Proposer une amélioration

1. Ouvrir une Issue avec le tag `enhancement`
2. Décrire la fonctionnalité souhaitée
3. Expliquer le cas d'usage (contexte PMR)
4. Attendre la validation avant de coder

### Soumettre du code

1. Fork le repository
2. Créer une branche depuis `main`
3. Implémenter les changements
4. Tester localement
5. Soumettre une Pull Request

## Standards de code

### Python (Backend)

```python
# Style : PEP 8
# Docstrings : Google style

def fonction_exemple(param: str) -> dict:
    """
    Description courte de la fonction.

    Args:
        param: Description du paramètre

    Returns:
        Description du retour

    Raises:
        ValueError: Si param est invalide
    """
    pass
```

**Outils recommandés** :
- `black` : Formatage automatique
- `isort` : Tri des imports
- `mypy` : Vérification des types
- `flake8` : Linting

```bash
# Formater
black backend/app/
isort backend/app/

# Vérifier
mypy backend/app/
flake8 backend/app/
```

### TypeScript/JavaScript (Frontend)

```typescript
/**
 * Description de la fonction.
 *
 * @param param - Description du paramètre
 * @returns Description du retour
 */
function fonctionExemple(param: string): Result {
  // ...
}
```

**Outils** :
- ESLint : Linting
- Prettier : Formatage (optionnel)

```bash
npm run lint
```

### Dart/Flutter (Mobile)

```dart
/// Description de la classe ou méthode.
///
/// [param] : Description du paramètre
/// Returns: Description du retour
Future<void> fonctionExemple(String param) async {
  // ...
}
```

**Outils** :
- `flutter analyze` : Analyse statique
- `dart format` : Formatage

```bash
flutter analyze
dart format lib/
```

### Commits

Format des messages de commit :

```
<type>(<scope>): <description>

[corps optionnel]

[footer optionnel]
```

**Types** :
| Type | Description |
|------|-------------|
| `feat` | Nouvelle fonctionnalité |
| `fix` | Correction de bug |
| `docs` | Documentation |
| `style` | Formatage (pas de changement de code) |
| `refactor` | Refactoring |
| `test` | Ajout/modification de tests |
| `chore` | Maintenance (deps, config) |

**Exemples** :
```
feat(backend): ajouter endpoint pour OCR
fix(mobile): corriger crash caméra sur Android 14
docs(readme): ajouter section architecture
```

## Processus de Pull Request

### Avant de soumettre

- [ ] Le code compile sans erreurs
- [ ] Les tests passent (`pytest`, `flutter test`)
- [ ] Le code est formaté (black, eslint)
- [ ] La documentation est à jour
- [ ] Pas de credentials dans le code

### Template de PR

```markdown
## Description
Brève description des changements.

## Type de changement
- [ ] Bug fix
- [ ] Nouvelle fonctionnalité
- [ ] Breaking change
- [ ] Documentation

## Comment tester
1. Étape 1
2. Étape 2
3. Résultat attendu

## Checklist
- [ ] J'ai testé mes changements
- [ ] J'ai mis à jour la documentation
- [ ] Le code suit les standards du projet
```

### Review

- Au moins 1 review requise avant merge
- Les commentaires doivent être constructifs
- Répondre à tous les commentaires avant merge

## Structure du projet

### Dossiers principaux

| Dossier | Responsabilité |
|---------|----------------|
| `backend/` | API FastAPI |
| `mobile_flutter/` | Application mobile |
| `web_next/` | Application web |
| `poc-web/` | Prototype TensorFlow.js |
| `docs/` | Documentation technique |
| `scripts/` | Scripts utilitaires |
| `datasets/` | Données d'entraînement |

### Conventions de nommage

| Type | Convention | Exemple |
|------|------------|---------|
| Fichiers Python | snake_case | `describe_image.py` |
| Fichiers TS/JS | camelCase ou kebab-case | `useCamera.ts` |
| Fichiers Dart | snake_case | `home_screen.dart` |
| Classes | PascalCase | `ImageAnalyzer` |
| Fonctions | camelCase (JS) / snake_case (Py) | `analyzeImage` / `analyze_image` |
| Constantes | UPPER_SNAKE_CASE | `MAX_RETRIES` |

## Questions ?

Pour toute question :
1. Consulter la documentation dans `/docs`
2. Ouvrir une Issue avec le tag `question`
3. Contacter l'équipe du projet

Merci de contribuer à rendre le monde plus accessible ! 🦯
