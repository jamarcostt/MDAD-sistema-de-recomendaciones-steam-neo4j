// src/app/dashboard/services/game.service.ts
import { Injectable, inject, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Game } from '../../shared/interfaces/game.interface';
import { TagCount, MetricComparison } from '../../shared/interfaces/statistics.interface';
import { AppUser } from '../../shared/interfaces/app-user.interface';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment.development';
// Ajusta la ruta

@Injectable({
  providedIn: 'root'
})

export class GamesService {
  private http = inject(HttpClient);

  // Signals de estado
  public games = signal<Game[]>([]);
  public topTags = signal<TagCount[]>([]);
  public isLoading = signal<boolean>(false);
  public API_URL = environment.baseUrl; 

  /**
   * Carga los juegos con mayor número de reseñas.
   */
  loadTopReviews(limit: number = 20): void {
    this.isLoading.set(true);
    const params = new HttpParams().set('limit', limit.toString());

    this.http.get<Game[]>(`${this.API_URL}/games/top-reviews`, { params }).subscribe({
      next: (data) => {
        this.games.set(data);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Error al cargar top reviews:', err);
        this.isLoading.set(false);
      }
    });
  }

  /**
   * Carga los juegos mejor valorados (% positivo).
   */
  loadTopRated(limit: number = 20): void {
    this.isLoading.set(true);
    const params = new HttpParams().set('limit', limit.toString());

    this.http.get<Game[]>(`${this.API_URL}/games/top-rated`, { params }).subscribe({
      next: (data) => {
        this.games.set(data);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Error al cargar top rated:', err);
        this.isLoading.set(false);
      }
    });
  }

  /**
   * Busca juegos que contengan una etiqueta específica.
   */
  loadGamesByTag(tagName: string, limit: number = 50): void {
    this.isLoading.set(true);
    const params = new HttpParams()
      .set('tagName', tagName)
      .set('limit', limit.toString());

    this.http.get<Game[]>(`${this.API_URL}/games/by-tag`, { params }).subscribe({
      next: (data) => {
        this.games.set(data);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error(`Error al cargar juegos por tag (${tagName}):`, err);
        this.isLoading.set(false);
      }
    });
  }

  /**
   * Lista las etiquetas más utilizadas en todo el catálogo.
   */
  loadTopTags(limit: number = 20): void {
    const params = new HttpParams().set('limit', limit.toString());

    this.http.get<TagCount[]>(`${this.API_URL}/tags/top`, { params }).subscribe({
      next: (data) => this.topTags.set(data),
      error: (err) => console.error('Error al cargar top tags:', err)
    });
  }

  /**
   * Busca juegos por nombre (coincidencia parcial) retornando un Observable.
   */
  searchGames(query: string, limit: number = 20): Observable<Game[]> {
    const params = new HttpParams()
      .set('q', query)
      .set('limit', limit.toString());

    return this.http.get<Game[]>(`${this.API_URL}/games/search`, { params });
  }

  /**
   * Obtiene la biblioteca del usuario actual
   */
  getUserLibrary(): Observable<AppUser> {
    return this.http.get<AppUser>(`${this.API_URL}/user/library`);
  }

  /**
   * Añade un juego a la biblioteca del usuario actual.
   */
  addGameToLibrary(appId: number): Observable<AppUser> {
    return this.http.post<AppUser>(`${this.API_URL}/user/library/${appId}`, {});
  }

  /**
   * Elimina un juego de la biblioteca del usuario actual.
   */
  removeGameFromLibrary(appId: number): Observable<AppUser> {
    return this.http.delete<AppUser>(`${this.API_URL}/user/library/${appId}`);
  }

  /**
   * Cuenta qué géneros/etiquetas predominan en la biblioteca.
   */
  getUserTagDistribution(): Observable<TagCount[]> {
    return this.http.get<TagCount[]>(`${this.API_URL}/user/tag-distribution`);
  }

  /**
   * Compara el precio medio de la biblioteca vs catálogo global.
   */
  getUserPriceComparison(): Observable<MetricComparison[] | MetricComparison> {
    return this.http.get<MetricComparison[] | MetricComparison>(`${this.API_URL}/user/price-comparison`);
  }

  /**
   * Compara la puntuación media de la biblioteca vs catálogo global.
   */
  getUserRatioComparison(): Observable<MetricComparison[] | MetricComparison> {
    return this.http.get<MetricComparison[] | MetricComparison>(`${this.API_URL}/user/ratio-comparison`);
  }

  /**
   * Devuelve etiquetas populares que el usuario no tiene.
   */
  getUserMissingTags(limit: number = 10): Observable<TagCount[]> {
    const params = new HttpParams().set('limit', limit.toString());
    return this.http.get<TagCount[]>(`${this.API_URL}/user/missing-tags`, { params });
  }

  // =========================================================================
  // MOTOR DE RECOMENDACIONES Y GRAFOS (NEO4J)
  // =========================================================================

  /**
   * Sugiere juegos combinando contenido y colaborativo.
   */
  getRecommendationsHybrid(limit: number = 20): Observable<Game[]> {
    const params = new HttpParams().set('limit', limit.toString());
    return this.http.get<Game[]>(`${this.API_URL}/user/recommendations/hybrid`, { params });
  }

  /**
   * Sugiere juegos similares a los que el usuario ya tiene.
   */
  getRecommendationsContent(limit: number = 20): Observable<Game[]> {
    const params = new HttpParams().set('limit', limit.toString());
    return this.http.get<Game[]>(`${this.API_URL}/user/recommendations/content`, { params });
  }

  /**
   * Sugiere juegos basados en usuarios con bibliotecas parecidas.
   */
  getRecommendationsCollaborative(limit: number = 20): Observable<Game[]> {
    const params = new HttpParams().set('limit', limit.toString());
    return this.http.get<Game[]>(`${this.API_URL}/user/recommendations/collaborative`, { params });
  }

  getGraphSimilarGames(): Observable<any[]> {
    return this.http.get<any[]>(`${this.API_URL}/user/graph/similar-games`);
  }

  getGraphRelatedTags(): Observable<any[]> {
    return this.http.get<any[]>(`${this.API_URL}/user/graph/related-tags`);
  }
}