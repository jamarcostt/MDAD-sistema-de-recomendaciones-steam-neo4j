// src/app/dashboard/pages/inicio-page/inicio-page.component.ts
import { Component, computed, inject, OnInit, signal } from '@angular/core'; // Ajusta la ruta
import { DecimalPipe, SlicePipe } from '@angular/common';
import { GamesService } from '../../services/games.service';

@Component({
  selector: 'app-inicio-page',
  standalone: true,
  imports: [DecimalPipe, SlicePipe],
  templateUrl: './inicio-page.component.html',
  // Si tienes CSS específico, añádelo aquí
})
export class InicioPageComponent implements OnInit {
  // Inyectamos el servicio de forma pública para usarlo en el HTML
  public gamesService = inject(GamesService);

  // Estado de los filtros
  public selectedTag: string = '';
  public selectedLimit: number = 18;// Para bindear al <select> como string
  public selectedSort: string = 'reviews'; // 'reviews' | 'rated'

  // Opciones de cantidad (múltiplos de 6 desde 18 hasta 120)
  public limitOptions: number[] = Array.from({ length: 18 }, (_, i) => (i + 3) * 6);

  // Array auxiliar para generar los skeletons de carga
  get skeletonArray() {
    return new Array(this.selectedLimit);
  }

  ngOnInit(): void {
    // 1. Cargamos las etiquetas para rellenar el <select>
    this.gamesService.loadTopTags(15);
    
    // 2. Cargamos los juegos iniciales con el límite por defecto
    this.loadGames();
  }

  /**
   * Se ejecuta cuando el usuario cambia el tipo de orden (Top reseñas o Top valorados)
   */
  onSortChange(event: Event): void {
    const selectElement = event.target as HTMLSelectElement;
    this.selectedSort = selectElement.value;
    // Al cambiar de orden, reiniciamos el filtro de etiquetas porque la API los maneja por separado
    this.selectedTag = '';
    this.loadGames();
  }

  /**
   * Se ejecuta cuando el usuario cambia la opción de la etiqueta en el <select>
   */
  onTagFilterChange(event: Event): void {
    const selectElement = event.target as HTMLSelectElement;
    this.selectedTag = selectElement.value;
    this.loadGames();
  }

  /**
   * Se ejecuta cuando el usuario cambia el límite de juegos en el <select>
   */
  onLimitChange(event: Event): void {
    const selectElement = event.target as HTMLSelectElement;
    this.selectedLimit = parseInt(selectElement.value, 10);
    this.loadGames();
  }

  /**
   * Helper para cargar los juegos dependiendo de los filtros actuales
   */
  private loadGames(): void {
    if (this.selectedTag === '') {
      // Si no hay etiqueta, cargamos según el orden seleccionado
      if (this.selectedSort === 'rated') {
        this.gamesService.loadTopRated(this.selectedLimit);
      } else {
        this.gamesService.loadTopReviews(this.selectedLimit);
      }
    } else {
      // Filtramos por la etiqueta seleccionada
      this.gamesService.loadGamesByTag(this.selectedTag, this.selectedLimit);
    }
  }
}