// src/app/dashboard/pages/inicio-page/inicio-page.component.ts
import { Component, computed, inject, OnInit, signal } from '@angular/core'; // Ajusta la ruta
import { DecimalPipe, SlicePipe } from '@angular/common';
import { GamesService } from '../../services/games.service';

@Component({
  selector: 'app-inicio-page',
  standalone: true,
  imports: [DecimalPipe, SlicePipe],
  templateUrl: './inicio-page.component.html',
})
export class InicioPageComponent implements OnInit {
  public gamesService = inject(GamesService);

  public selectedTag: string = '';
  public selectedLimit: number = 18;
  public selectedSort: string = 'reviews';

  public limitOptions: number[] = Array.from({ length: 18 }, (_, i) => (i + 3) * 6);

  get skeletonArray() {
    return new Array(this.selectedLimit);
  }

  ngOnInit(): void {
    this.gamesService.loadTopTags(15);
    
    this.loadGames();
  }

  /**
   * Se ejecuta cuando el usuario cambia el tipo de orden (Top reseñas o Top valorados)
   */
  onSortChange(event: Event): void {
    const selectElement = event.target as HTMLSelectElement;
    this.selectedSort = selectElement.value;
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
      if (this.selectedSort === 'rated') {
        this.gamesService.loadTopRated(this.selectedLimit);
      } else {
        this.gamesService.loadTopReviews(this.selectedLimit);
      }
    } else {
      this.gamesService.loadGamesByTag(this.selectedTag, this.selectedLimit);
    }
  }
}