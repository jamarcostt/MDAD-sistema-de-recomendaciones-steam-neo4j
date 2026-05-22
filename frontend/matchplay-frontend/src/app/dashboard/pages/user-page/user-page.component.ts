import { ChangeDetectionStrategy, Component, inject, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { DecimalPipe, SlicePipe } from '@angular/common';
import { GamesService } from '../../services/games.service';
import { Game } from '../../../shared/interfaces/game.interface';
import { AppUser } from '../../../shared/interfaces/app-user.interface';
import { TagCount, MetricComparison } from '../../../shared/interfaces/statistics.interface';

@Component({
  selector: 'app-user-page',
  standalone: true,
  imports: [FormsModule, DecimalPipe, SlicePipe],
  templateUrl: './user-page.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UserPageComponent implements OnInit {
  public gamesService = inject(GamesService);

  public user = signal<AppUser | null>(null);
  public searchResults = signal<Game[]>([]);
  public searchQuery = signal<string>('');
  public isSearching = signal<boolean>(false);

  // Señales para el resumen de estadísticas
  public tagDistribution = signal<TagCount[]>([]);
  public priceComparison = signal<MetricComparison | null>(null);
  public ratioComparison = signal<MetricComparison | null>(null);
  public missingTags = signal<TagCount[]>([]);

  ngOnInit(): void {
    this.loadLibrary();
    this.loadStats();
  }

  loadLibrary(): void {
    this.gamesService.getUserLibrary().subscribe({
      next: (user) => this.user.set(user),
      error: (err) => console.error('Error al cargar la biblioteca', err)
    });
  }

  loadStats(): void {
    this.gamesService.getUserTagDistribution().subscribe(res => this.tagDistribution.set(res));
    
    this.gamesService.getUserPriceComparison().subscribe(res => {
      const data = Array.isArray(res) ? res[0] : res;
      this.priceComparison.set(data as MetricComparison);
    });
    
    this.gamesService.getUserRatioComparison().subscribe(res => {
      const data = Array.isArray(res) ? res[0] : res;
      this.ratioComparison.set(data as MetricComparison);
    });
    
    this.gamesService.getUserMissingTags(10).subscribe(res => this.missingTags.set(res));
  }

  addToLibrary(appId: number, event: Event): void {
    event.stopPropagation();
    this.gamesService.addGameToLibrary(appId).subscribe({
      next: (updatedUser) => {
        this.user.set(updatedUser);
        this.loadStats();
      },
      error: (err) => {
        console.error('Error al añadir el juego a la biblioteca', err);
      }
    });
  }

  removeFromLibrary(appId: number, event: Event): void {
    event.stopPropagation();
    this.gamesService.removeGameFromLibrary(appId).subscribe({
      next: (updatedUser) => {
        this.user.set(updatedUser);
        this.loadStats();
      },
      error: (err) => {
        console.error('Error al eliminar el juego de la biblioteca', err);
      }
    });
  }

  onSearch(): void {
    const query = this.searchQuery().trim();
    if (!query) {
      this.searchResults.set([]);
      return;
    }

    this.isSearching.set(true);
    this.gamesService.searchGames(query, 20).subscribe({
      next: (games) => {
        this.searchResults.set(games);
        this.isSearching.set(false);
      },
      error: (err) => {
        console.error('Error en la búsqueda', err);
        this.isSearching.set(false);
      }
    });
  }
}
