import { ChangeDetectionStrategy, Component, inject, OnInit, signal, effect, ViewChild, ElementRef } from '@angular/core';
import { DecimalPipe, SlicePipe } from '@angular/common';
import { GamesService } from '../../services/games.service';
import { Game } from '../../../shared/interfaces/game.interface';
import * as d3 from 'd3';

@Component({
  selector: 'app-resumen-page',
  standalone: true,
  imports: [DecimalPipe, SlicePipe],
  templateUrl: './resumen-page.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ResumenPageComponent implements OnInit {
  public gamesService = inject(GamesService);
  @ViewChild('d3Container', { static: true }) d3Container!: ElementRef;

  public activeGraph = signal<'games' | 'tags'>('games');
  private simulation: any;

  // Señales de Recomendaciones
  public hybridRecs = signal<Game[]>([]);
  public contentRecs = signal<Game[]>([]);
  public collabRecs = signal<Game[]>([]);

  public graphSimilarGames = signal<any[]>([]);
  public graphRelatedTags = signal<any[]>([]);

  constructor() {
    effect(() => {
      const gamesData = this.graphSimilarGames();
      const tagsData = this.graphRelatedTags();
      const active = this.activeGraph();

      if (this.d3Container?.nativeElement) {
        this.renderGraph(active, gamesData, tagsData);
      }
    });
  }

  ngOnInit(): void {
    this.loadRecommendations();
  }

  public loadRecommendations(): void {
    this.gamesService.getRecommendationsHybrid(8).subscribe(data => this.hybridRecs.set(data));
    
    this.gamesService.getRecommendationsContent(4).subscribe(data => this.contentRecs.set(data));
    
    this.gamesService.getRecommendationsCollaborative(4).subscribe(data => this.collabRecs.set(data));

    this.gamesService.getGraphSimilarGames().subscribe(data => this.graphSimilarGames.set(data));
    this.gamesService.getGraphRelatedTags().subscribe(data => this.graphRelatedTags.set(data));
  }

  /**
   * Añade el juego recomendado a la biblioteca y lo quita visualmente de las listas
   */
  public addToLibrary(appId: number, event: Event): void {
    event.stopPropagation();
    this.gamesService.addGameToLibrary(appId).subscribe({
      next: () => {
        this.hybridRecs.update(recs => recs.filter(g => g.appId !== appId));
        this.contentRecs.update(recs => recs.filter(g => g.appId !== appId));
        this.collabRecs.update(recs => recs.filter(g => g.appId !== appId));
        
      },
      error: (err) => console.error('Error al añadir juego desde descubrir', err)
    });
  }

  // =========================================================================
  // VISUALIZACIÓN CON D3.JS
  // =========================================================================

  private renderGraph(active: 'games' | 'tags', gamesData: any[], tagsData: any[]): void {
    const container = this.d3Container.nativeElement;
    d3.select(container).selectAll('*').remove();
    if (this.simulation) this.simulation.stop();

    // 1. Preparar Nodos y Enlaces dependiendo del grafo elegido
    const nodesMap = new Map<string | number, any>();
    const links: any[] = [];

    if (active === 'games' && gamesData.length > 0) {
      gamesData.forEach(edge => {
        if (!nodesMap.has(edge.sourceId)) nodesMap.set(edge.sourceId, { id: edge.sourceId, label: edge.sourceTitle, group: 1 });
        if (!nodesMap.has(edge.targetId)) nodesMap.set(edge.targetId, { id: edge.targetId, label: edge.targetTitle, group: 2 });
        links.push({ source: edge.sourceId, target: edge.targetId, value: edge.shared });
      });
    } else if (active === 'tags' && tagsData.length > 0) {
      tagsData.forEach(edge => {
        if (!nodesMap.has(edge.source)) nodesMap.set(edge.source, { id: edge.source, label: edge.source, group: 3 });
        if (!nodesMap.has(edge.target)) nodesMap.set(edge.target, { id: edge.target, label: edge.target, group: 3 });
        links.push({ source: edge.source, target: edge.target, value: edge.weight });
      });
    } else {
      return;
    }

    const nodes = Array.from(nodesMap.values());
    const width = container.clientWidth || 800;
    const height = container.clientHeight || 600;

    // 2. Configurar SVG y Zoom
    const svg = d3.select(container)
      .append('svg')
      .attr('width', '100%')
      .attr('height', '100%')
      .attr('viewBox', [0, 0, width, height] as any);

    const g = svg.append('g');

    svg.call(d3.zoom().scaleExtent([0.1, 4]).on('zoom', (event) => {
      g.attr('transform', event.transform);
    }) as any);

    // 3. Configurar Motor de Fuerzas (Física)
    this.simulation = d3.forceSimulation(nodes as any)
      .force('link', d3.forceLink(links).id((d: any) => d.id).distance(active === 'games' ? 120 : 80))
      .force('charge', d3.forceManyBody().strength(-400))
      .force('center', d3.forceCenter(width / 2, height / 2));

    // 4. Dibujar Líneas
    const link = g.append('g')
      .attr('stroke', '#a6adbb')
      .attr('stroke-opacity', 0.4)
      .selectAll('line')
      .data(links)
      .join('line')
      .attr('stroke-width', (d: any) => Math.min(Math.max(d.value, 1), 5)); // Grosor según el peso

    // 5. Dibujar Nodos interactivos
    const node = g.append('g')
      .selectAll('g')
      .data(nodes)
      .join('g')
      .call(d3.drag()
        .on('start', (event: any, d: any) => { if (!event.active) this.simulation.alphaTarget(0.3).restart(); d.fx = d.x; d.fy = d.y; })
        .on('drag',  (event: any, d: any) => { d.fx = event.x; d.fy = event.y; })
        .on('end',   (event: any, d: any) => { if (!event.active) this.simulation.alphaTarget(0); d.fx = null; d.fy = null; }) as any
      );

    node.append('circle')
      .attr('r', (d: any) => d.group === 3 ? 12 : 8)
      .attr('fill', (d: any) => d.group === 1 ? '#00a96e' : (d.group === 2 ? '#ff5861' : '#00b5ff'))
      .attr('stroke', '#191e24').attr('stroke-width', 2);

    node.append('text')
      .text((d: any) => d.label)
      .attr('x', 14).attr('y', 4)
      .attr('fill', '#e6e6e6').style('font-size', '12px').style('font-weight', 'bold')
      .style('pointer-events', 'none').style('text-shadow', '0px 2px 4px rgba(0,0,0,0.8)');

    // 6. Actualización en cada tick de la física
    this.simulation.on('tick', () => {
      link.attr('x1', (d: any) => d.source.x).attr('y1', (d: any) => d.source.y)
          .attr('x2', (d: any) => d.target.x).attr('y2', (d: any) => d.target.y);
      node.attr('transform', (d: any) => `translate(${d.x},${d.y})`);
    });
  }
}